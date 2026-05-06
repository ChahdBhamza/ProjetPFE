"""
DetectronService — wraps Facebook AI Detectron2 for object detection/segmentation.
Falls back gracefully if Detectron2 is not installed.
"""

import io
import base64
from PIL import Image


class DetectronService:
    """
    Lazy-loaded Detectron2 inference service.
    Uses Mask R-CNN R-50-FPN 3x (COCO pretrained) by default.
    """

    COCO_CLASSES = [
        "__background__", "person", "bicycle", "car", "motorcycle", "airplane",
        "bus", "train", "truck", "boat", "traffic light", "fire hydrant",
        "stop sign", "parking meter", "bench", "bird", "cat", "dog", "horse",
        "sheep", "cow", "elephant", "bear", "zebra", "giraffe", "backpack",
        "umbrella", "handbag", "tie", "suitcase", "frisbee", "skis",
        "snowboard", "sports ball", "kite", "baseball bat", "baseball glove",
        "skateboard", "surfboard", "tennis racket", "bottle", "wine glass",
        "cup", "fork", "knife", "spoon", "bowl", "banana", "apple",
        "sandwich", "orange", "broccoli", "carrot", "hot dog", "pizza",
        "donut", "cake", "chair", "couch", "potted plant", "bed",
        "dining table", "toilet", "tv", "laptop", "mouse", "remote",
        "keyboard", "cell phone", "microwave", "oven", "toaster", "sink",
        "refrigerator", "book", "clock", "vase", "scissors", "teddy bear",
        "hair drier", "toothbrush",
    ]

    def __init__(self):
        self.predictor = None
        self.cfg = None
        self._available = False
        self._load_model()

    def _load_model(self):
        """Try to load Detectron2 model (lazy, won't crash if not installed)."""
        try:
            import detectron2
            from detectron2.engine import DefaultPredictor
            from detectron2.config import get_cfg
            from detectron2 import model_zoo

            cfg = get_cfg()
            cfg.merge_from_file(
                model_zoo.get_config_file(
                    "COCO-InstanceSegmentation/mask_rcnn_R_50_FPN_3x.yaml"
                )
            )
            cfg.MODEL.ROI_HEADS.SCORE_THRESH_TEST = 0.5   # confidence threshold
            cfg.MODEL.WEIGHTS = model_zoo.get_checkpoint_url(
                "COCO-InstanceSegmentation/mask_rcnn_R_50_FPN_3x.yaml"
            )
            # Use CPU if no CUDA — slower but always available
            cfg.MODEL.DEVICE = "cuda" if self._has_cuda() else "cpu"

            self.cfg = cfg
            self.predictor = DefaultPredictor(cfg)
            self._available = True
            print(
                f"[DetectronService] Loaded Mask R-CNN on {cfg.MODEL.DEVICE.upper()}"
            )
        except ImportError:
            print(
                "[DetectronService] Detectron2 not installed. "
                "Install from: https://detectron2.readthedocs.io/en/latest/tutorials/install.html"
            )
            self._available = False
        except Exception as e:
            print(f"[DetectronService] Failed to load model: {e}")
            self._available = False

    @staticmethod
    def _has_cuda() -> bool:
        try:
            import torch
            return torch.cuda.is_available()
        except ImportError:
            return False

    def is_available(self) -> bool:
        return self._available

    # ------------------------------------------------------------------ #
    #  Core inference                                                       #
    # ------------------------------------------------------------------ #

    def run_inference(self, image: Image.Image) -> dict:
        """
        Run Detectron2 inference on a PIL image.

        Returns
        -------
        dict with keys:
            annotated_image : PIL.Image  (image with boxes + masks drawn)
            detections      : list[dict] (class, score, box)
            device          : str
            model           : str
        """
        if not self._available:
            raise RuntimeError(
                "Detectron2 is not installed. "
                "Please install it following https://detectron2.readthedocs.io/"
            )

        import numpy as np
        import cv2
        from detectron2.utils.visualizer import Visualizer
        from detectron2.data import MetadataCatalog

        # PIL → BGR numpy (Detectron2 expects BGR)
        img_rgb = np.array(image.convert("RGB"))
        img_bgr = cv2.cvtColor(img_rgb, cv2.COLOR_RGB2BGR)

        # Run model
        outputs = self.predictor(img_bgr)
        instances = outputs["instances"].to("cpu")

        # ---- Build structured detections list ----
        detections = []
        boxes  = instances.pred_boxes.tensor.numpy() if instances.has("pred_boxes")  else []
        scores = instances.scores.numpy()             if instances.has("scores")       else []
        classes= instances.pred_classes.numpy()       if instances.has("pred_classes") else []

        for i, (box, score, cls_id) in enumerate(zip(boxes, scores, classes)):
            x1, y1, x2, y2 = box.tolist()
            class_name = (
                self.COCO_CLASSES[cls_id + 1]   # +1 because index 0 is __background__
                if (cls_id + 1) < len(self.COCO_CLASSES)
                else f"class_{cls_id}"
            )
            detections.append({
                "id":    i,
                "class": class_name,
                "score": round(float(score), 4),
                "box":   [round(v, 1) for v in [x1, y1, x2, y2]],
            })

        # Sort by confidence descending
        detections.sort(key=lambda d: d["score"], reverse=True)

        # ---- Draw annotations using Detectron2 Visualizer ----
        metadata = MetadataCatalog.get(self.cfg.DATASETS.TRAIN[0])
        visualizer = Visualizer(img_rgb, metadata=metadata, scale=1.0)
        vis_output = visualizer.draw_instance_predictions(instances)
        annotated_bgr = vis_output.get_image()   # returns RGB already

        annotated_pil = Image.fromarray(annotated_bgr)

        device = self.cfg.MODEL.DEVICE
        return {
            "annotated_image": annotated_pil,
            "detections":      detections,
            "device":          device,
            "model":           "Mask R-CNN R-50-FPN 3x (COCO)",
            "count":           len(detections),
        }

    # ------------------------------------------------------------------ #
    #  Utility                                                              #
    # ------------------------------------------------------------------ #

    @staticmethod
    def pil_to_base64(image: Image.Image) -> str:
        buf = io.BytesIO()
        image.save(buf, format="JPEG", quality=90)
        return base64.b64encode(buf.getvalue()).decode("utf-8")
