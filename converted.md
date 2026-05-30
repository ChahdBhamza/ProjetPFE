Code PFE: BD-04
### Ministry of Higher Education and Scientific Research
### University of Manouba
### Higher Institute of Multimedia Arts
### End of Studies Project Report
### Presented for the Bachelor’s Degree in Big Data and Data Analysis
# Intelligent Equipment Detection: Multimodal
# LLM and Web Intelligence Powered System
### Completed at
### Prepared by:
### Chahd Ben Hamza
### Supervised by:
### Ms. Mariem Noemen (SFM)
### Ms. Imen Belhadj (ISAMM)
### Academic Year: 2025/2026

---

## DEDICATIONS
To my beloved parents,
The blossom of my heart and the light that never fades. Your everlasting love, continuous
sacrifices, and deep belief in my potential have been the anchor keeping me grounded
and moving forward throughout my entire academic path. From the bottom of my heart,
thank you for protecting my ambitions and for being my ultimate sanctuary through
every hardship and triumph. If this accomplishment is a harvest, it is only because of
your steady, loving hands.
To my brother and sister,
The two souls entwined with mine whom I cannot imagine navigating a single moment
without. Thank you for the endless laughs, the invaluable life lessons, and the pure
comfort of being truly seen and understood. You are the pillars that keep me strong,
always keeping track of my horizons and ensuring I never lose my way.
To my dearest friends,
The family I chose along this journey. Thank you for the shared late nights, the endless
encouragement, and the beautiful distraction of your laughter when the stress became
overwhelming. Your presence turned this long academic pursuit into an unforgettable
adventure, and I am deeply grateful for your constant support.

---

## ACKNOWLEDGEMENTS
First and foremost, I must express my deepest gratitude to my academic supervisor, Mrs.
Mariem Noemen, for her invaluable guidance, patient supervision, and constructive
feedback throughout the development of this graduation project. Her academic expertise
and continuous encouragement were instrumental in shaping the structure and quality
of this work.
I would like to extend my sincere thanks to my technical supervisor, Mrs. Imen Belhadj,
for welcoming me and providing me with a rich learning environment. Her technical
insights, practical mentorship, and daily support greatly enhanced my understanding
and problem-solving skills throughout this journey.
Finally, I am also deeply grateful to the entire team at SFM Technologies. Thank you
for providing the professional resources, data workspace, and collaborative environment
necessary to bring this project to fruition. The hands-on experience gained alongside
your team has been truly invaluable to my growth as a future professional.

---

# Contents
General Introduction 1
1 Business Understanding 2
1.1 Introduction . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 2
1.2 Host Organization Overview . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 2
1.2.1 Overview . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 2
1.2.2 Core Business Activities . . . . . . . . . . . . . . . . . . . . . . . . . . . . 2
1.2.3 Strategic Services . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 3
1.3 Project Overview . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 4
1.3.1 Project Context . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 4
1.3.2 Business Need . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 4
1.3.3 Business Objective . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 4
1.3.4 Project Objectives . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 5
1.3.5 General Objective . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 5
1.3.6 Strategic Axes of Development . . . . . . . . . . . . . . . . . . . . . . . . . 5
1.4 Study of the Existing Situation . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 5
1.4.1 Problem Statement . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 5
1.4.2 Critique of the Existing Situation . . . . . . . . . . . . . . . . . . . . . . . 6
1.5 Proposed Solution: An Intelligent Maintenance Assistant . . . . . . . . . . . . . . . 6
1.6 Specifications of Requirements . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 7
1.6.1 Functional Requirements . . . . . . . . . . . . . . . . . . . . . . . . . . . . 7
1.6.2 Non-Functional Requirements . . . . . . . . . . . . . . . . . . . . . . . . . 8
1.7 Project Development Methodologies . . . . . . . . . . . . . . . . . . . . . . . . . . 8
1.7.1 CRISP-DM . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 8
1.7.2 SEMMA . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 9
1.7.3 GIMSI . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 10
1.7.4 Comparison of Methodologies . . . . . . . . . . . . . . . . . . . . . . . . . 10
1.7.5 Adopted Methodology: Why CRISP-DM? . . . . . . . . . . . . . . . . . . . 10
1.7.6 Conclusion . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 12
2 Foundational Concepts and Tools 13
2.1 Introduction . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 13
2.2 Concepts . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 13
2.2.1 Artificial Intelligence . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 13
2.2.2 Machine Learning . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 13
i

---

CONTENTS
2.2.3 Deep Learning & Neural Networks . . . . . . . . . . . . . . . . . . . . . . 14
2.2.4 Computer Vision & Image Enhancement . . . . . . . . . . . . . . . . . . . 15
2.2.5 Object Detection Models (YOLO & RF-DETR) . . . . . . . . . . . . . . . . 16
2.2.6 Temporal Stabilization & the Hero Frame Strategy . . . . . . . . . . . . . . 16
2.2.7 Large Language Models & Vision-Language Models . . . . . . . . . . . . . 17
2.2.8 Retrieval-Augmented Generation . . . . . . . . . . . . . . . . . . . . . . . . 17
2.3 Tools & Technologies . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 18
2.3.1 Development Environment & Coding Architecture . . . . . . . . . . . . . . 18
2.3.2 Backend Frameworks & API Management . . . . . . . . . . . . . . . . . . . 18
2.3.3 Computer Vision & Object Detection Pipelines . . . . . . . . . . . . . . . . 19
2.3.4 YOLOv5 (Ultralytics) . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 19
2.3.5 RF-DETR . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 19
2.3.6 Roboflow . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 19
2.3.7 AI Models & Language Orchestration Platforms . . . . . . . . . . . . . . . . 20
2.3.8 Google AI Studio . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 20
2.3.9 OpenRouter . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 20
2.3.10 Web Search & Data Extraction . . . . . . . . . . . . . . . . . . . . . . . . . 20
2.3.11 BeautifulSoup . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 20
2.3.12 User Interface . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 20
2.4 Summary of Technical Architecture . . . . . . . . . . . . . . . . . . . . . . . . . . 21
2.5 Conclusion . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 21
3 Data Understanding and Preparation 22
3.1 Introduction . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 22
3.2 Data Sources Overview . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 22
3.2.1 Raw Mobile Video Streams (Primary Input) . . . . . . . . . . . . . . . . . . 23
3.2.2 Annotated Visual Training Sets (Model Intelligence) . . . . . . . . . . . . . 23
3.2.3 Web-Scraped Specification Pages (Dynamic Knowledge) . . . . . . . . . . . 24
3.3 Exploratory Analysis of Raw Video Data . . . . . . . . . . . . . . . . . . . . . . . . 24
3.4 Dataset Description and Retrieval Approach Evolution . . . . . . . . . . . . . . . . 25
3.4.1 Target Equipment Classes . . . . . . . . . . . . . . . . . . . . . . . . . . . 26
3.4.2 Evolution: Knowledge Base to Live Scraping . . . . . . . . . . . . . . . . . 26
3.4.3 Custom Air Conditioner Dataset . . . . . . . . . . . . . . . . . . . . . . . . 26
3.4.4 From Knowledge Base to Live Pipeline . . . . . . . . . . . . . . . . . . . . 27
3.5 Data Preparation Pipeline: Seven-Stage Architecture . . . . . . . . . . . . . . . . . 27
3.5.1 Stage 1: Video Extraction and Data Expansion . . . . . . . . . . . . . . . . 27
3.5.2 Stage 2: Sharpness-Based Quality Analysis . . . . . . . . . . . . . . . . . . 29
3.5.3 Stage 3:The YOLOv5s Gatekeeper and Frame Scoring . . . . . . . . . . . . 31
3.5.4 Stage 4:Cloud-Based Precision Inference via Roboflow Workflows . . . . . . 32
3.5.5 Stage 5:Final Hero Frame Selection . . . . . . . . . . . . . . . . . . . . . . 35
3.5.6 Stage 6: Enhancement — Image Preprocessing for Optical Character Recognition 37
ii

---

CONTENTS
3.5.7 Stage 7: Specification Retrieval — Web Data Cleaning via DOM Decomposition 38
3.6 Conclusion . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 39
Webography 40
iii

---

# List of Figures
1.1 SFM Technologies Logo . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 2
2.1 Python programming language logo. . . . . . . . . . . . . . . . . . . . . . . . . . . 18
2.2 Visual Studio Code logo. . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 18
2.3 FastAPI web framework logo. . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 19
2.4 Roboflow computer vision platform logo. . . . . . . . . . . . . . . . . . . . . . . . 20
2.5 Flutter UI toolkit logo. . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 21
3.1 High-Level Data Optimization Flow. . . . . . . . . . . . . . . . . . . . . . . . . . . 22
3.2 System Modality Hierarchy and Data Sources. . . . . . . . . . . . . . . . . . . . . . 23
3.3 Three consecutive frames at 30 fps illustrating temporal redundancy . . . . . . . . . 24
3.4 Real-time sharpness analysis comparing a blurry panning sequence (Frame 42) with a
stabilized camera view (Frame 96). . . . . . . . . . . . . . . . . . . . . . . . . . . . 30
3.5 YOLOv5 local gatekeeper execution comparing an empty background sequence (left)
with a valid target appliance detection (right). . . . . . . . . . . . . . . . . . . . . . 31
3.6 The Roboflow cloud workflow. . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 34
3.7 A real Hero Frame output from the system: a refrigerator detected at 97.56% confidence
with a labeled bounding box rendered by the Roboflow cloud pipeline. . . . . . . . . 35
3.8 The finalized hero frame output . . . . . . . . . . . . . . . . . . . . . . . . . . . . 36
3.9 Visual impact of the CLAHE algorithm on localized luminance. . . . . . . . . . . . 38
iv

---

# List of Tables
1.1 Methodologies Comparison . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 11
2.1 Machine Learning example techniques and applications . . . . . . . . . . . . . . . . 14
2.2 Tools and Technologies Summary Table . . . . . . . . . . . . . . . . . . . . . . . . 21
3.1 Summary of video quality challenges and their mitigations. . . . . . . . . . . . . . . 25
3.2 Video Extraction and Data Measurements. . . . . . . . . . . . . . . . . . . . . . . . 28
v

---

LIST OF TABLES
AI Artificial Intelligence
API Application Programming Interface
BI Business Intelligence
CLAHE Contrast Limited Adaptive Histogram Equalization
COCO Common Objects in Context
COSAP SFM Digitalization and RPA Product
CPU Central Processing Unit
CRISP-DM Cross Industry Standard Process for Data Mining
DETR Detection Transformer
DL Deep Learning
DOM Document Object Model
GIMSI Generalized Integrated Management System Intelligence
ICT Information and Communication Technologies
ISAMM Higher Institute of Multimedia Arts of Manouba
ITM SFM Digitalization and RPA Product
ITU-D International Telecommunication Union – Development Sector
JSON JavaScript Object Notation
LLM Large Language Model
ML Machine Learning
MP4 MPEG-4 Part 14
NGN Next Generation Network
NLP Natural Language Processing
NMS Non-Maximum Suppression
PKI Public Key Infrastructure
QoS Quality of Service
RAG Retrieval-Augmented Generation
REST Representational State Transfer
RF-DETR Roboflow Detection Transformer
ROI Region of Interest
vi

---

LIST OF TABLES
RPA Robotic Process Automation
SAS Statistical Analysis System
SEMMA Sample, Explore, Modify, Model, Assess
SOC Security Operations Center
UI User Interface
VLLM Vision Large Language Model
YOLO You Only Look Once
vii

---

# General Introduction
In the field of ICT, the capacity to comprehend visual data from video streams can act as a significant
yet frequently overlooked source of innovation. At present, identifying the capabilities of technical
infrastructure manually is one of the primary constraints that exists. It is a time consuming and
mistake-prone procedure, which complicates scalability.
Through linking unprocessed video data with actionable knowledge, artificial intelligence (AI) enables
companies to transition from manual monitoring to an effective, automated digital system.
However, traditional computer vision methods face significant limitations, as they typically require
intensive training procedures and massive annotated datasets. The solution to overcome these limitations
by eliminating the manual process which consumes much of human effort comes through a multimodal
retrieval augmented generation (RAG) architecture. The use of machine learning, algorithms, and
LLMs in order to design a zero-training model which will recognize the equipment using external
technical knowledge. This approach aims to implement an automated system that drastically reduce the
resources usually required for infrastructure management.
Guided by this vision, we developed the Multimodal Video RAG System for Automatic Equipment
Detection as a way of tacking the needs for digitalization today. In terms of the project execution, the
CRISP-DM methodology was adopted due to its iterative and efficient cycles, which are well suited to
data-driven project development.
1

---

# Chapter 1
# Business Understanding
### 1.1 ### Introduction
In this chapter we will be focusing on the foundation of the project, by starting with a presentation of
the host organization and the project itself. From there, the chapter evaluates current operational needs
to justify the proposed solution and set a clear business objective, concluding with the methodology
adopted for project management.
### 1.2 ### Host Organization Overview
### 1.2.1 ### Overview
Services for Fixed and Mobile Telecommunications Network and Systems (SFM Technologies) is
a Tunisian engineering firm that was established in 1995 by a team of specialized engineers and
consultants, and is a member of the International Telecommunication Union (ITU-D). SFM Technologies
has developed into a multi-disciplinary firm that is delivering high-value consultancy and technical
excellence to an elite international client base, such as ministries of telecommunication, regulatory
authorities, frequency agencies, network operators, and international financial institutions, for over
three decades in Africa, Asia, Europe, the united states, and Oceania.
Figure 1.1: SFM Technologies Logo
### 1.2.2 ### Core Business Activities
SFM has four strategic pillars that underpin its operations:
A. Technical Expertise: SFM uses high-level engineering for the audit and benchmarking of
mobile network Quality of Service (QoS) against international standards, including network
planning, dimensioning, traffic analysis, and spectrum management.
B. Strategic Consulting: SFM Technologies acts as a strategic consultant to ICT Ministries and
regulatory bodies to navigate the challenges of sector reform and legal regulation, manages
2

---

CHAPTER 1. Business Understanding
the management of scarce resources such as spectrum pricing, and manages end-to-end
licensing processes. Additionally, SFM facilitates large-scale technology migrations, helping
stakeholders transition to advanced architectures such as LTE, 3G, and NGN.
C. Research & Development (SFM Lab): SFM Technologies retains a competitive advantage by
maintaining a SFM Lab with a team of engineers and academic researchers who collaborate on
innovative telecommunications projects. Specifically, the department focuses on developing
advanced signal propagation and communication models, as well as sophisticated traffic
analysis techniques, to create proprietary tools and methodologies for Quality of Service
(QoS) evaluation. As a result, the firm to remain current with the latest emerging industry
standards and technological developments.
D. Professional Training: SFM Technologies offers high-end customized programs to develop
operational independence in client teams, which primarily focus on advanced QoS measurement
techniques and digital transformation, delivered through a flexible approach (on-site, in the
field, or in SFM dedicated facilities) so that experts can transfer technical competencies to
clients for them to manage their own network infrastructures.
### 1.2.3 ### Strategic Services
SFM provides services that are both technical and organizational, as well as custom-made training
with high added value, thus positioning itself as a true strategic partner for its clients. Its solutions and
custom developments are structured around three main areas:
• Digitalization & RPA: SFM Technologies improves operational efficiency by helping organiza-
tions move from legacy systems to agile solutions using RPA. Through products such as COSAP,
and ITM, it supports companies in automating and optimizing their business processes.
• Cybersecurity: SFM Technologies meets modern digital challenges by providing unique cyber
security solutions. These solutions span the deployment of a Security Operations Center (SOC),
enterprise PKI for secure identity assurance and secured Wi-Fi access portals to control and
encrypt access to the network.
• Big Data & Artificial Intelligence: SFM’s core Big Data and AI operations is essentially about
transforming large data sets into usable knowledge through ML and DL. Whether for the external
telecommunications or banking sectors where they apply their predictive models to things such as
fraud prevention, customer churn and exchange rate forecasting, or internally with their software
products which they equip with AI to tackle demanding industrial problems.
3

---

CHAPTER 1. Business Understanding
### 1.3 ### Project Overview
### 1.3.1 ### Project Context
At the heart of this analytical pipeline is the systematic identification and profiling of physical assets,
which detects and categorizes equipment in technical environments to qualify them for a structured
digital inventory.
The Multimodal Video-RAG architecture replaces manual inspections with high-accuracy results
from the analysis of a single video stream that converts raw visual data into organized records for
assets ranging from IT infrastructure and cooling systems to office and kitchen appliances, effectively
shortening the path from field observation to actionable enterprise data.
### 1.3.2 ### Business Need
In the rapidly changing world of the modern industry, companies are constantly under the pressure of
optimizing technical processes irrespective of their domain. Advanced technical solutions are required
to deal with the challenges associated with the collection of internal data and improve the performance
of their operations.
In particular, the engineering company SFM Technologies can benefit from having the opportunity
to control its assets efficiently. It becomes crucial to have a system that resolves the logistical issues
associated with manual site inspections. Instead of a time-consuming inspection process, it would be
reasonable to consider adopting smart detection technologies that guarantee fast and accurate reporting
based on quality data. This information will be used as a basis for making strategic decisions and
generating profit from operations.
The issue of controlling the physical assets of the engineering company SFM Technologies is one of
the most important problems to solve. The number of various assets present in any given area varies
greatly. Each asset is characterized by different brands, models, and configurations. Therefore, it
would be unwise to use human inspectors to manually collect technical data. It is important to find a
"training-free" and ready to deploy approach capable of detecting assets of various classes automatically
to enhance productivity and ensure data accuracy in engineering reports.
### 1.3.3 ### Business Objective
The core goal of this project is the digitization of the auditing process for SFM Technologies through
the use of an artificial intelligence driven solution that will replace labor-intensive manual audits with
automated procedures. The proposed AI system utilizes one-step analysis, which automatically converts
visual data to technical documentation in one step, thus providing an automatic process from capturing
the video footage to generating the technical documents with a view to ensuring data consistency and
reducing auditing tasks.
4

---

CHAPTER 1. Business Understanding
### 1.3.4 ### Project Objectives
The first step will be closing the gap between technical complexity and the level of understanding.
Operators find it difficult to recognize equipment and access information on their properties in real time.
The project uses a smart, multi-sensor system that includes both visual recognition of the equipment
and real-time Internet retrieval to replace manual recognition with automated recognition technology
based on LLM reasoning and real-time data processing.
### 1.3.5 ### General Objective
To design and develop a mobile application capable of identifying technical equipment through
video analysis and providing grounded assistance to optimize maintenance efficiency and knowledge
accessibility at SFM Technologies.
### 1.3.6 ### Strategic Axes of Development
To achieve the general goal, the project is divided into the following strategic axes:
Technical Excellence: Intelligent Multimodal Verification Pipeline
Create an intelligent system that is capable of extracting the details related to the equipment using
videos while retrieving the technical specs from the internet in real time. The LLM uses both the
streams for reasoning on the equipment and comes up with accurate findings much faster than the
manual process.
Functional Innovation: Automated Identification & Tracking
design a user-friendly interface where one will be able to identify and authenticate the equipment
through video uploads without much hassle. The system will provide details about the equipment found,
specifications as well as the accuracy level. The operator will have access to validated information
without having to look up information from different sources.
Operational & Social Impact: Efficiency and Knowledge Accessibility
Through automation of the identification and specification search process for assets, the system ensures
that field engineers are able to allocate their time efficiently towards carrying out complex technical
tasks. The centralization of real-time equipment data helps in bridging the gap between information
possessed by experienced and inexperienced engineers.
### 1.4 ### Study of the Existing Situation
### 1.4.1 ### Problem Statement
Equipment identification is a crucial operational task that provides the base for technical inventories
and infrastructure management. Currently, this process relies on manual audits in the field, where
technicians visit each site to find assets and then write down the equipment and technical details on
5

---

CHAPTER 1. Business Understanding
a label (such as brand, model, and electrical capacity) and manually enter it into digital systems to
update the database.
### 1.4.2 ### Critique of the Existing Situation
While the manual approach serves its basic purpose, it presents several fundamental challenges that
significantly impact overall productivity and data integrity:
• Significant Time Consumption: The process of visiting locations and manually assessing each
piece of equipment is inherently slow, resulting in "reporting latency" that obstructs prompt
strategic decision-making.
• Risk of Inconsistency: Manually collecting data poses the risk of human error, for instance,
misidentifying assets or incorrect technical information.
• Operational Inefficiency: The heavy dependency on manual data entry forces the team to spend
time on tasks that can be done through automation, which in return limits scalability across the
entire process.
• Difficulty in Verification: Manually entered records are often unverified due to the absence
of visuals that can validate the data provided. Therefore, a double check on the veracity of the
record is essential, indicating a considerable gap in data traceability.
### 1.5 ### Proposed Solution: An Intelligent Maintenance Assistant
In order to resolve the above challenges, it is proposed that the Automated Identification Assistant be
developed. Instead of manually checking the labels, which is both time-consuming and laborious, an
efficient new process has been created for using up human energy without "lost time".
The proposed solution is built on three main pillars:
1. Smart Visual Identification: With the help of a mobile application developed using Flutter, the
user records the video containing an appliance, like a printer, air conditioner, microwave, etc.
The system analyses the appliances from various angles in order to recognize the proper brand
and model and other technical specifications.
2. Knowledge-Integrated Retrieval (RAG): The assistant uses Retrieval-Augmented Generation
(RAG) architecture. This implies that upon recognizing the device, the system automatically
fetches accurate technical information about it from the knowledge base, acting as a "bridge"
between the actual hardware and its technical specifications.
3. Automated Digital Reporting: The Large Language Model (LLM) guarantees that all the
retrieved data will be integrated into one technical document. There is no need for manual data
input since all the data will be provided in JSON format. The reason why the JSON format is
used is to input the data accurately and in a proper way into the company’s inventory management
system.
6

---

CHAPTER 1. Business Understanding
In order to overcome the above-mentioned problems, the suggested solution is an Automated Identifica-
tion Assistant system. This solution involves automation of the existing manual identification system
with the aim of improving efficiency and minimizing wasted efforts.
### 1.6 ### Specifications of Requirements
In order to implement the objectives of the project into a technical solution, certain requirements have
been put together that will control how the system performs and what are the standard specifications
for the system. Requirements can be categorized into functional and non-functional requirements,
depending upon the functions of the system.
### 1.6.1 ### Functional Requirements
1. Video-Based Detection
• The system must allow the user to upload a video of an appliance (Refrigirator, AC, Microwave)
or upload an existing file.
• The system must analyze the video stream and extract "key frames" to identify the equipment
and it’s specifications.
• The system must send validated frames to cloud-based RF-DETR for high-precision object
localization and bounding box extraction
2. Multimodal LLM Analysis & Content Generation
• Multimodal Image Ingestion: The system must securely forward the curated visual Hero
Frame and its verified computer vision tag to a cloud-based Multimodal Large Language Model
(VLLM).
• Intelligent Feature Extraction: The system must utilize the VLLM’s reasoning loops to isolate
deep technical attributes, serial numbers, or model markings visible directly on the device.
• Structured Serialization: The system must process the model’s analytical output and generate
a structured technical report (JSON format) containing all finalized equipment attributes.
3. AI Content Generation
• The system must use an LLM to process and summarize the retrieved data into a user-friendly
format.
• The system must generate a structured technical report (JSON) containing all identified attributes.
4. User Interface (Mobile)
• The system must provide a clear dashboard for the technician to view detection results.
• The system must allow the user to save or export the generated technical data.
7

---

CHAPTER 1. Business Understanding
### 1.6.2 ### Non-Functional Requirements
1. Accuracy and Reliability
• Detection Precision: Equipment detection must achieve high confidence scores to minimize
false positives.
• Specification Accuracy:Retrieved specifications must be sourced from current, verified vendors
to ensure technical correctness.
2. Usability & Accessibility
• Ease of Use: The mobile interface must be intuitive for field operators without requiring deep
technical AI knowledge.
• Visual Clarity::The mobile display must present information clearly with appropriate text size
and contrast for field visibility
3. Interoperability
• Structured Output: The output must be provided in JSON format so it can integrate easily with
company inventory management or database systems.
4. Performance
• Latency: Although the project is not real-time, the delay between video upload and result
generation should be optimized to reduce lost time for staff.
### 1.7 ### Project Development Methodologies
In this section, we analyze the different frameworks available to manage the lifecycle of our project,
focusing on methodologies that bridge the gap between technical data mining and business objectives.
### 1.7.1 ### CRISP-DM
Cross Industry Standard Process for Data Mining (CRISP-DM) is an open standard process model
which can be used freely by anyone, with no restrictions. It is one of the most famous methodologies in
the field of data mining and the most commonly used model to conduct data science projects.
CRISP-DM has six main phases that go as the following:
1. Business Understanding: The primary focus is on understanding the business objectives and
defining the project’s goals and requirements. Business understanding plays a key role in this
process since it involves such steps as determining key business ideas, performance metrics for
measuring success, and the scope of the project.
2. Data Understanding: The process involves collecting, identifying, and analyzing data sets in
order to get acquainted with the available data and to evaluate its quality. This involves collecting
8

---

CHAPTER 1. Business Understanding
and describing the data in its raw form with the aim of comprehending the data features and their
significance in the business issue.
3. Data Preparation: This is the final stage for data preparation for modeling purposes. The
objective of this phase might consist of some different kind of tasks as handling the missing/null
values, removing duplications, unifying data format etc. In this stage, non-relevant data and
columns are removed. Apart from the cleaning aspects, this phase is also associated with feature
engineering which includes the construction of a number of new data values, that will help
achieve the project goals, transform categorical data to machine learnable format and identify
features to be used by the model. Such a phase requires a lot of work and time because the
project relies heavily on the quality of the data and it is stated by data mining experts that this
stage represents by far the largest phase of a project.
4. Modeling: In this phase, multiple modeling approaches are selected and used to apply to the
preprocessed data in order to develop predictive or descriptive models. In this process, proper
algorithms with their parameters have to be chosen, the models need to be trained and evaluated
for their performance through several validation techniques.
5. Evaluation: The evaluation phase involves the evaluation of the models built in the previous
phase against certain criteria that would help achieve success with respect to the project. While
the major consideration in building the models in the previous phase was their technical accuracy,
the major considerations in this phase become whether the models serve the business purposes
and how to improve the models in terms of meeting the business goals.
6. Deployment: This phase comes as the last step when taking a developed model from testing
to actual business use. It mainly aims to make sure the model’s results fit well within business
processes. This phase also includes proper documentation and planning which help keep
performance steady over time. It ends with a final project review.
### 1.7.2 ### SEMMA
SEMMA is an approach to data mining created by SAS Institute and comprises Sample, Explore,
Modify, Model, and Assess. SEMMA provides a solid roadmap for predictive modeling. This approach
is recognized as the best way to organize the entire analysis process. SEMMA suits well in situations
when there is a demand for high precision from the standpoint of statistics. By using it sequentially,
one can effectively turn the raw data into meaningful models.
• Sample: It is the initial component of the SEMMA model that involves selection of all the data
but is more efficient to work with a subset. It is not aimed at reducing the size of the data but to
ensure that the portion chosen reflects the trends of the entire dataset. A high-quality sample
speeds up the modeling process a lot and keeps accuracy intact.
• Explore: In this step, the selected data would be analyzed in order to gain insight into the data.
This will be done through exploratory data analysis whereby the data would be analyzed in terms
9

---

CHAPTER 1. Business Understanding
of descriptive statistics and visualization to see relationships and factors influencing the modeling
process.
• Modify: This is where the application of data processing comes in. As the first data set gets
converted into a structured form that can be applied for modeling. Basically, this entails making
sure that all the useful information available from the data set is maximized for predictive analysis
purposes and this includes such activities as the imputation of missing and outlier values as well
as data normalization.
• Model: At this level, a range of data mining techniques and statistical models are implemented
on the structured data in order to produce a prediction model. It involves exploring relationships
in the data to achieve prediction of certain values of variables. The selected model depends on
the need of business.
• Assess: This last stage makes sure the business requirements are fulfilled. The model gets
evaluated and tested on another data set which checks its accuracy and allows for any last changes
before implementation.
### 1.7.3 ### GIMSI
GIMSI is a Business Intelligence (BI) Framework. It is used to align information systems with the
business strategy by defining Key Performance Indicators (KPIs) and decision support dashboards. It
does not focus on data science techniques, but rather management objectives. It is especially suited for
projects with an end goal of presenting management with a visual picture of their operations.
### 1.7.4 ### Comparison of Methodologies
To evaluate the most suitable framework for this project, the following table provides a synthesis and
comparison of the main aspects of each methodology:
### 1.7.5 ### Adopted Methodology: Why CRISP-DM?
The choice of the methodological approach known as CRISP-DM (cross-industry standard process for
data mining) for this project was made after thorough analysis of various methodologies available. The
choice of CRISP-DM as opposed to other methodologies is mainly because of the fact that it is more
focused towards achieving the business goals.
The selection was derived from the following core factors:
• Iterative and Cyclical Nature: Such an AI-driven system need to be highly flexible. CRISP-
DM advocates non-linear flow and enable essential feedback loop such as going back to Data
Preparation phase after technical Evaluation. This allows us to improve our multimodal data
extraction and model accuracy over time.
• Strategic Business Alignment: The key to the current approach for SFM Technologies is
increasing the efficiency of the technical auditing process and customer engagement. The
10

---

CHAPTER 1. Business Understanding
Methodology CRISP-DM SEMMA GIMSI
Number of Phases 6 5 4
Approach Converts business goals
into tasks to ensure
strategic project align-
ment.
Uses a structured techni-
cal workflow to prepare
data and optimize model
performance.
Focuses on the end-user
to create dashboards that
support organizational
decision-making.
Application Commonly used in
large-scale Data Science
and AI projects.
Commonly used for
technical research and
statistical modeling.
Commonly used for
Business Intelligence
and decision-support
systems.
Advantages End-to-End: Seam-
lessly connects business
strategy to implementa-
tion with high flexibility
and efficiency.
Technical Depth: Ef-
fective for technical data
preparation and isolated
algorithm refinement.
User Adoption: Pro-
vides a flexible way to
define key metrics and
align data with manage-
ment decisions.
Limitations Maintains a high-level
focus on business strat-
egy rather than technical
tool selection.
Incomplete Scope:
Lacks initial business
alignment and critical
post-deployment moni-
toring.
Procedural Rigidity:
Lacks the technical
agility for AI prototyp-
ing, focusing on admin-
istrative metrics.
Table 1.1: Methodologies Comparison
11

---

CHAPTER 1. Business Understanding
business understanding component forms the base of the approach so that all technical milestones
are driven by the strategic objectives of the business.
• End-to-End Delivery: CRISP-DM provides a complete roadmap for the project trajectory. It
guarantees a structured progression from the definition of the requirements until the deployment
of the developed system giving total control over the development process.
• Industry Standard: Being the most widely known method for Data Science, it offers a reliable
and trusted base. Its use in different sectors means projects follow a globally tested structure
which makes it the best choice for delivering top-quality AI and Big Data solutions.
### 1.7.6 ### Conclusion
In this chapter, we outline the project’s basic context by introducing the host organization and identifying
key challenges and goals. Choosing the CRISP-DM method gives us a structured plan which keeps
technical quality and business alignment.
This framework gives guidance for the next State of the Art chapter. We will look into the main
technologies which include object detectionn, multimodal LLMs and orchestration tools which are the
technical backbone of our final solution.
12

---

# Chapter 2
# Foundational Concepts and Tools
### 2.1 ### Introduction
This chapter covers the theoretical background and technical tools that form the foundation of this
project. It is structured into three parts: the core concepts — from artificial intelligence and computer
vision through large language models, agentic web search, and the Hero Frame strategy; the technologies
selected for the pipeline and the reasoning behind each choice; and the data sources the system relies
on along with the challenges they introduce.
### 2.2 ### Concepts
### 2.2.1 ### Artificial Intelligence
Artificial Intelligence (AI) is a branch of science that integrates computing, engineering, and mathematics
in creating software that performs actions comparable to what is done using human intelligence. These
actions entail learning, natural language processing, recognizing patterns, solving complex problems,
and making logical judgments.
The system’s performance is not attributable to a single powerful feature, but rather to several features
coordinated together. Computer vision detects and localizes equipment in video. A multimodal
language model reasons about visual proof and checks it with a given specification. An agentic search
module fetches real-time product information on its own, with no manual search required. Each module
does something the others cannot, and it is their combined output when pipelined that produces a kind
of output that none of them could produce on their own.
### 2.2.2 ### Machine Learning
Machine learning is an area of study under artificial intelligence, where algorithms can be developed to
perform better by learning from data. The beauty of machine learning is that one does not need to
feed the computer a manual; rather, the computer learns for itself by analyzing the labeled data and
discovering patterns too complex for any person to code on his own. This knowledge gained is then
used to make classifications, regressions, clusterings, and intelligent decisions, making it possible for
the computer to work with new and unseen data.
Now we will go through the main types of machine learning (ML):
13

---

CHAPTER 2. Foundational Concepts and Tools
• Supervised Learning: This involves training the model by feeding it a certain data set, wherein
both input as well as output data sets are known (labels). For prediction purposes, an appropriate
mapping from input to output must be derived.
• Unsupervised Learning: With regard to this algorithm, the processing of the information occurs
in the computer without any direction or prior classification. The main objective of the algorithm
is the identification of underlying structures and statistical associations. It is significant in the
clustering of Big Data and the simplification of feature spaces.
• Reinforcement Learning: This algorithm involves models learning optimal actions via trial and
error, adjusting strategies through environmental rewards and penalties, enabling agents to solve
sequential decision-making problems adaptively.
Technique ML Type Description and Example
Classification Supervised Learning Sorting data into specific categories based on
labeled training. Example: Identifying if an
email is "Spam" or "Not Spam".
Regression Supervised Learning Predicting a specific numerical value along a
continuous scale. Example: Estimating the
price of a car based on its age.
Clustering Unsupervised Learning Finding patterns to group unlabeled data by sim-
ilarities. Example: Grouping customers into
"Frequent Buyers" or "One-time Shoppers".
Q-Learning Reinforcement Learning Improving actions through a feedback loop of re-
wards and penalties. Example: A robot learning
the fastest path through a warehouse by avoiding
obstacles.
Table 2.1: Machine Learning example techniques and applications
### 2.2.3 ### Deep Learning & Neural Networks
Deep Learning refers to an aspect of machine learning, whereby multiple layers of artificial neural
networks are used. Within this context, every layer receives inputs from the preceding layer, undergoes
mathematical transformations, and sends its outputs to the subsequent layer. The higher the number of
layers, the greater the likelihood of forming abstraction representations, which explains the effectiveness
of deep learning when dealing with unstructured data like images, sounds, and texts.
The neural network consists of units known as neurons organized into distinct layers. The input layer
takes in the unprocessed data; for instance, in the case of an image, the raw pixel values. The output
layer gives the final prediction. What lies in between is the conversion of the signal from one form to
another through hidden layers. Every individual neuron in the network conducts computations on its
input, where it computes the linear combination of its inputs based on learned weights, and applies
14

---

CHAPTER 2. Foundational Concepts and Tools
some form of nonlinearity (activation function) to that combination prior to delivering its result as
input to other neurons. The network learns from adjustments driven by errors discovered during the
training process.
In visual tasks, this process produces something remarkable — without anyone programming it
explicitly, early layers learn to detect basic edges and gradients, middle layers build complex shapes
and textures, and deeper layers recognize complete objects. It emerges entirely from the data itself.
For this project, the primary vision and language models (YOLOv5, RF-DETR, and Gemini Flash 1.5)
are not designed or trained from the ground up. They are existing pre-trained deep learning models.
Knowing how they work under the hood gives us a better sense of what they can do, where they will
break, and why we made the architectural decisions we did.
### 2.2.4 ### Computer Vision & Image Enhancement
Computer vision refers to the branch of artificial intelligence that allows computers to derive semantic
meaning from visual data, including images and videos. Computer vision differs from traditional image
processing techniques, which typically focus on modifying the raw pixel values using geometric or
filtering techniques. The computer vision technique is more advanced because it involves interpreting
the semantic contents within a scene to comprehend identities and interactions. In the current project,
computer vision functions as the initial point of structural interaction.
Three tasks define most of what computer vision systems do:
• Image Classification: Refers to assigning a single categorical label to the entire image, such as
“this is a refrigerator.”
• Object Detection: Identifies and locates one or more items within an image by generating a
class label and localized coordinates (a bounding box) for each detected object.
• Image Segmentation: Provides a pixel-level analysis by assigning a class label to every individual
pixel in the image.
One-Stage vs. Two-Stage Detection: Localization architectures treat regional extraction from
distinct operational perspectives. Two-stage detectors involve a sequential pipeline where region
proposals are generated first and subsequently classified, ensuring higher spatial precision at the
cost of execution latency. Single-stage detectors perform both spatial localization and categorical
classification simultaneously in a single forward pass, rendering them highly performant for streaming
video processing tasks. Transformer-based object detectors introduce an entirely new paradigm by
substituting anchor configurations with learned object queries that model dependencies across the entire
visual context using attention mechanism pathways. This project leverages both a one-stage model and
a transformer-based detector, assigning each to a role that optimizes its explicit functional strengths.
15

---

CHAPTER 2. Foundational Concepts and Tools
Image Enhancement for Forensic Readability: Detecting equipment in a video frame is only the
initial technical step. The cropped region of interest that reaches Gemini Flash 1.5 must be visually
readable; brand logos, model alphanumeric strings, and certification labels need to be crisp enough
for the model to interpret details with high confidence. Raw video feeds do not always guarantee this
clarity, as any given frame can be underexposed, slightly blurred by field motion, or lacking local
contrast in the exact sectors containing identifying indicators.
To address this, the pipeline applies a dedicated image enhancement stage to every extracted crop before
it reaches the language model, using classical computer vision techniques — specifically contrast
enhancement and sharpening to maximize the legibility of fine text and visual patterns. The explicit
algorithmic details and hyperparameters of this enhancement stage are detailed in Chapter 3.
### 2.2.5 ### Object Detection Models (YOLO & RF-DETR)
YOLO & YOLOv5: YOLO — You Only Look Once — reformulates object detection as a single
regression problem, predicting bounding boxes and class labels for all objects globally in one forward
pass through the network. This single-pass design makes it substantially faster than two-stage
architectures. YOLOv5 organizes this architecture into three major operational components: a
backbone that extracts multi-scale feature representations from the input image, a neck that fuses those
features to handle objects of widely varying sizes, and a detection head that outputs the final bounding
box coordinates, objectness metrics, and class probabilities.
RF-DETR — The Precise Detector: Detection Transformers (the DETR family) approach object
detection differently. Rather than predicting objects through anchor-based regression loops, DETR
combines a Transformer encoder-decoder architecture with a set of learned object queries. Each
query maps to a distinct asset by attending globally across the entire image space via self-attention
mechanisms. This removes the need for anchor configurations and post-processing steps like Non-
Maximum Suppression (NMS) to eliminate duplicate boxes. The global attention framework makes
these models robust against occlusions, non-standard viewpoints, and cluttered physical environments.
RF-DETR is Roboflow’s optimized deployment of this transformer architecture, pretrained on COCO
datasets and executed via an endpoint inference pipeline.
### 2.2.6 ### Temporal Stabilization & the Hero Frame Strategy
Video streams introduce a structural challenge that static image processing does not encounter — frame
quality varies dynamically over time. Any individual frame may be compromised by motion blur,
localized occlusion, erratic exposures, or compression codecs. Forwarding a randomly sampled frame
to a visual language model introduces the risk of providing an unreadable image as the base for a
verification query — a downstream point of failure that no amount of prompt engineering can salvage.
The Hero Frame strategy addresses this challenge by treating a sliding temporal window of consecutive
frames as an active candidate pool, selecting the single highest-fidelity frame using a multi-criteria
16

---

CHAPTER 2. Foundational Concepts and Tools
scoring function. Three parameters are calculated for each candidate frame: the localized RF-DETR
prediction confidence score, the high-frequency image sharpness measured via the variance of the
Laplacian operator, and the spatial stability of the bounding box coordinates across neighboring frames.
The frame maximizing this multi-variable metric is isolated as the Hero Frame — the explicit visual
input sent to the vision-language model for brand extraction and downstream document verification.
### 2.2.7 ### Large Language Models & Vision-Language Models
Large Language Models: A Large Language Model (LLM) is a deep neural network trained on
vast text corpora, developing the capacity to comprehend syntax, recall factual assertions, and reason
through structured analytical workflows. The underlying core technologies of modern language models
include:
• Artificial Neural Networks (ANNs): Layered structural systems where computational nodes
apply learned mathematical weights to input states. These networks are optimized by minimizing
prediction errors using backpropagation routines until the weights generalize reliably across
unseen inputs.
• The Transformer Architecture: Replaced recurrent sequencing models by introducing self-
attention mechanisms. This approach allows the network to process text segments in parallel and
evaluate long-range contextual relationships across tokens in a single operational step.
• Natural Language Processing (NLP): The encompassing computer science domain focused on
enabling computational systems to analyze, parse, and translate human languages, supporting
tasks like information retrieval, semantic modeling, and structured generation.
Vision-Language Models (VLMs): A Vision-Language Model extends text-based architectures to
ingest and interpret images and text tokens simultaneously within a unified feature space. A dedicated
visual encoder converts the input image or crop into a sequence of continuous visual tokens. These
visual embeddings are concatenated directly with standard textual tokens and processed sequentially
through the main Transformer backbone. This structural fusion ensures the model reasons across
both modalities at the same time — directly mapping spatial details observed in the visual feed to
the assertions found in text — instead of running isolated vision and language tracks and trying to
reconcile them later.
In this pipeline, Gemini Flash 1.5 receives the enhanced Hero Frame crop alongside the autonomously
retrieved web technical specification text within a single prompt, allowing it to perform cross-modal
reasoning to evaluate whether the physical asset matches its verified engineering documentation.
### 2.2.8 ### Retrieval-Augmented Generation
Retrieval-Augmented Generation (RAG) is the process of optimizing the output of a large language
model, so it references an authoritative knowledge base outside of its training data sources before
17

---

CHAPTER 2. Foundational Concepts and Tools
generating a response. Large Language Models (LLMs) are trained on vast volumes of data and
use billions of parameters to generate original output for tasks like answering questions, translating
languages, and completing sentences. RAG extends the already powerful capabilities of LLMs to
specific domains or an organization’s internal knowledge base, all without the need to retrain the model.
It is a cost-effective approach to improving LLM output so it remains relevant, accurate, and useful in
various contexts. 
[W1]
### 2.3 ### Tools & Technologies
To translate these architectural concepts into a working solution, a pipeline was constructed using
highly modular, performant frameworks. The following sections detail the technologies selected and
the strategic reasoning behind their integration.
### 2.3.1 ### Development Environment & Coding Architecture
Python is a high-level, general-purpose programming language that has become the standard in
artificial intelligence and data-driven development. Its readable syntax and vast ecosystem of
specialized libraries make it well suited for building complex multi-stage systems. The entire backend
orchestration framework of this project is implemented natively in Python.
Figure 2.1: Python programming language logo.
Visual Studio Code is a lightweight, open-source code editor developed by Microsoft, supporting a
wide range of programming languages through an extensive library of extensions. It was used as the
primary development environment throughout this project for writing, debugging, and managing the
backend codebase.
Figure 2.2: Visual Studio Code logo.
### 2.3.2 ### Backend Frameworks & API Management
FastAPI is a modern, high-performance Python web framework for building REST APIs, supporting
asynchronous request handling and automatic API documentation generation. In this project, it serves
18

---

CHAPTER 2. Foundational Concepts and Tools
as the central backend framework that orchestrates the entire pipeline — receiving streaming video
uploads from the mobile app, coordinating the vision models, managing web scrapers, and returning
the structured JSON validation results.
Figure 2.3: FastAPI web framework logo.
FFmpeg is an open-source multimedia framework used for decoding and processing video and audio
files across a wide range of formats and codecs. In this project, it handles the underlying extraction of
individual frames from uploaded video files, converting raw footage into a sequential image queue
ready for object detection.
### 2.3.3 ### Computer Vision & Object Detection Pipelines
OpenCV (Open Source Computer Vision Library) is an open-source library offering a comprehensive
set of tools for image analysis and processing. In this project, it operates dynamically on the frames
isolated by FFmpeg — executing region-of-interest cropping around bounding box coordinates and
applying the forensic image enhancement pipeline (contrast and sharpening) before feeding the crop to
the vision-language model.
### 2.3.4 ### YOLOv5 (Ultralytics)
is a real-time object detection model developed by Ultralytics, pretrained on the COCO dataset. In this
project, it serves as an efficient first-pass frame filter — scanning incoming video frames at high speed,
discarding those that contain no relevant equipment categories, and passing qualified frames forward to
reduce computing overhead.
### 2.3.5 ### RF-DETR
is a transformer-based object detection model optimized by Roboflow, pretrained on COCO and served
through a managed inference API. In this project, it acts as the primary precise detector responsible
for producing high-confidence class-level detections and precise bounding coordinates for the target
categories: refrigerator, microwave, laptop, and air conditioner.
### 2.3.6 ### Roboflow
is an end-to-end computer vision platform covering dataset annotation, augmentation, training, and
deployment workflows. In this project, it serves a dual role: as the engineering environment used to
annotate and augment the custom air conditioner dataset, and as the host architecture for the RF-DETR
inference endpoint executed during pipeline runtime.
19

---

CHAPTER 2. Foundational Concepts and Tools
Figure 2.4: Roboflow computer vision platform logo.
### 2.3.7 ### AI Models & Language Orchestration Platforms
Google Gemini Flash 1.5 is a multimodal large language model developed by Google DeepMind,
capable of processing images and text together within a single context window. In this project, it
handles both brand extraction from the enhanced Hero Frame crop and the downstream verification of
engineering specifications against web-retrieved product documentation.
### 2.3.8 ### Google AI Studio
is the prototyping and development environment provided by Google for interacting with Gemini
models. It was utilized during the engineering phase of this project to design, iterate, and evaluate the
structural prompting strategies applied to Gemini Flash 1.5.
### 2.3.9 ### OpenRouter
is an API gateway providing unified access to a wide range of large language models through a single
endpoint. It was used during the integration testing phase of this project as an elastic access route to
Gemini models before configuring dedicated production infrastructure.
### 2.3.10 ### Web Search & Data Extraction
DuckDuckGo Search is a privacy-focused web search engine accessible programmatically through the
duckduckgo-search library without requiring rigid developer API keys. In this project, it is used by
the agentic module to autonomously retrieve current technical product pages based on the brand and
model strings extracted from the visual feed.
### 2.3.11 ### BeautifulSoup
is a Python library for parsing HTML documents and extracting structured content from web pages.
In this project, it processes the raw markup pages retrieved by DuckDuckGo to extract the clean,
unformatted specification text injected directly into the Gemini verification prompt.
### 2.3.12 ### User Interface
Flutter is an open-source UI toolkit developed by Google for building natively compiled iOS and
Android applications from a single Dart codebase. In this project, it powers the mobile frontend
through which the field operator captures or uploads video, interacts with the backend API, and displays
the final verification record — presenting the identified asset class, extracted model metrics, and the
generated digital twin record.
20

---

CHAPTER 2. Foundational Concepts and Tools
Figure 2.5: Flutter UI toolkit logo.
### 2.4 ### Summary of Technical Architecture
To provide a consolidated view of the architectural components, Table 2.2 synthesizes how each library
and tool functions within the encompassing infrastructure.
Library / Tool Category Purpose in the Project
Python Development Environment Backend language for the entire pipeline
Visual Studio Code Development Environment Primary code editor and debugging environment
FastAPI Backend & API Async REST API — pipeline orchestration
FFmpeg Backend & API Video frame extraction from uploaded footage
Pydantic Backend & API Data schema validation across pipeline stages
python-dotenv Backend & API API key and environment variable management
OpenCV Computer Vision & Detection ROI cropping and image enhancement
YOLOv5 (Ultralytics) Computer Vision & Detection First-pass frame filtering
RF-DETR Computer Vision & Detection Precise equipment detection — 4 classes
Roboflow Computer Vision & Detection Dataset management and RF-DETR API hosting
Gemini Flash 1.5 AI & LLM Brand extraction and specification verification
Google AI Studio AI & LLM Development and prompt prototyping
OpenRouter AI & LLM Testing and model access gateway
DuckDuckGo Search Web Search & Data Retrieval Autonomous web query execution
BeautifulSoup (bs4) Web Search & Data Retrieval HTML parsing
Flutter / Dart User Interface Cross-platform mobile frontend
Table 2.2: Tools and Technologies Summary Table
### 2.5 ### Conclusion
As established in this chapter, the selected concepts and technologies define a layered architecture
where each tool addresses a precise functional requirement. These foundations directly inform the data
preparation pipeline presented in Chapter 3.
21

---

# Chapter 3
# Data Understanding and Preparation
### 3.1 ### Introduction
Automated detection and verification systems require high-quality, clean data to function accurately.
Raw field data rarely meets this requirement. Field-captured video contains motion blur, uninformative
empty frames, and high temporal redundancy. Web-scraped specifications arrive wrapped in non-
semantic boilerplate — navigation menus, scripts, styling information. Processing degraded inputs
directly is costly: cloud APIs waste resources on noisy frames; language models waste computational
attention on HTML boilerplate. The quality of data flowing into the system directly determines the
quality of outputs.
Data preprocessing is performed to enhance the quality of the data by using two procedures working
concurrently, and they consist of the visual procedure whereby blur is removed, filtering and detection
is done, duplicate images are removed, and improved visibility is provided, and the text procedure
whereby relevant data is extracted.
This chapter documents the seven stages of this preprocessing strategy, their design rationale, demon-
strated effectiveness, and how together they establish the clean data foundation required for reliable
appliance detection and verification.
Raw Field Inputs
(Visual & Text Noise)
Multi-Stage Pipeline
(Algorithmic Cleaning)
Optimized Inputs
(Clean Semantic Data)
Figure 3.1: High-Level Data Optimization Flow.
### 3.2 ### Data Sources Overview
The detection methodology for our forensics appliance is built around the use of three specific types of
data, each of which plays its own specific role in the process. This does not involve the interaction with
just one central database.Rather,the process acts as a dynamic system that integrates information from
various different data types including local models,cloud models,and live web sources.
22

---

CHAPTER 3. Data Understanding and Preparation
1. Raw Mobile Video Streams
(Primary Field Input)
2. Annotated Training Sets
(YOLOv5 Local Screening / RF-DETR)
3. Web Specification Pages
(Live Vendor Scraping)
Figure 3.2: System Modality Hierarchy and Data Sources.
### 3.2.1 ### Raw Mobile Video Streams (Primary Input)
The core telemetry data that mainly constitutes the input to the system is directly collected from the
field. The collection is achieved through the use of a unique cross-platform Flutter mobile client that
captures videos of the target appliance in its environment.
The video payload is transmitted as a compressed H.264 MP4 file container at standard mobile
resolutions—specifically 720p (1280 × 720) or 1080p (1920 × 1080) at a native frame rate of 30 frames
per second (fps). Because video captures continuous sequential frames over time, it naturally introduces
high temporal data redundancy and a massive volume of raw pixels. This creates a critical downstream
processing bottleneck that the preprocessing pipeline must mitigate through targeted frame selection.
### 3.2.2 ### Annotated Visual Training Sets (Model Intelligence)
In order for us to efficiently detect devices and filter unnecessary image frames, we utilize special
datasets of appliances labeled with bounding boxes. This dataset, which has undergone curation and
versioning through Roboflow workspace, was used in training two layers in our vision workflow:
1. Local Edge Layer: A highly optimized, lightweight yolov5s model variant configured to run
locally on the edge device to provide near-instantaneous frame screening and validation.
2. Cloud Inference Layer: A custom cloud-hosted Roboflow Workflow pipeline utilizing high-
capacity and precision detection models like RF-DETR (Recurrent Feature Detection Transformer)
to achieve precise object isolation and multi-class asset classification.
Both the yolov5s model used locally and the RF-DETR framework used from the cloud use transfer
learning techniques. The initial backbone is trained using the Microsoft COCO (Common Objects in
Context) data, giving very reliable initial parameters that will be used to detect common geometric
shapes, edges, and textures as well as generic features of appliances found within a domestic environment.
23

---

CHAPTER 3. Data Understanding and Preparation
Using this as a basis, both algorithms are fine-tuned on our domain-specific data to attain precision and
recall.
### 3.2.3 ### Web-Scraped Specification Pages (Dynamic Knowledge)
Once the identification and classification of the appliance asset are properly done, the system will use
intelligent methods to obtain information about technical characteristics of the appliance asset through
publicly available web pages like manufacturer and ecommerce sites. The technique uses real-life
characteristics of assets which are not readily available in closed datasets.
Text extraction pipeline is based on BeautifulSoup parser that scans the HTML DOM tree and
extracts the relevant text blocks from it. The technical information including dimensions, electrical
characteristics, capacity, etc. is separated from the page layout noise and the information itself is
serialized in a clear text schema free from any presentation layer information.
This abstraction technique enhances the precision of subsequent text generation processes by generating
structurally clear,semantically dense documents devoid of any presentation noise, thus ensuring that
reasoning algorithms operate using pure technical metadata.
### 3.3 ### Exploratory Analysis of Raw Video Data
Before the processing begins, it is critical to evaluate the input into the system. The unprocessed video
taken in the field is drastically different from structured data sets utilized for computer vision research.
It contains the unpredictability associated with hand-held video capture, in which the operator moves
around inside an equipment area capturing a series of frames, of which very few are exploitable.
In order to illustrate this quantitatively, an inspection video clip was used whose total length was 28.92
seconds, resulting in a total of 862 images recorded at 29.80 fps with 576 x 1024 pixel resolution.
On the surface, 862 images can appear to be a substantial amount of visual data. However, most of
the frames will either look similar to each other or will have problems posed by four common issues
related to mobility.
Figure 3.3: Three consecutive frames at 30 fps illustrating temporal redundancy
24

---

CHAPTER 3. Data Understanding and Preparation
### Motion Blur
Spatial malformation occurs because of fast panning of the camera, hand shakes of the videographer,
and abrupt changes in auto focus during filming. Edges of objects become blurry and out-of-focus,
including brand logos, markings on panels, and even serial numbers, thus making these features useless
for identification purposes.
### Temporal Redundancy
At 30 frames per second, consecutive frames captured while the operator is stationary share over 95%
of their pixel information. Processing every frame linearly scales computational and API costs with
zero added value. Yet skipping frames at fixed intervals risks capturing a degraded mid-motion frame.
What the system needs is not uniform sampling but quality-driven selection.
### Variable Indoor Illumination
Real-world equipment rooms introduce unpredictable lighting. Fluorescent overhead lighting shifts
color balance toward green or yellow hues. Natural light from windows creates specular glare on shiny
surfaces, while lit areas spaces produce underexposed images where chassis shapes and identification
labels are barely distinguishable.
### Spatial Resolution and Compression Artifacts
Using H.264 compression, streams are encoded at 720p or 1080p. This format works well for
transmission but causes localized block artifacts and blurs out fine textures precisely the ones used in
printed labels and brand logos that the identification system relies on.
The table below correlates each challenge with its assessed impact and the mitigation technique utilized
by the preprocessing pipeline:
Challenge Effect on Detection Mitigation
Motion Blur False negatives, low confidence Laplacian Variance filter
Temporal Redundancy (30 fps) Wasted compute, high API cost Sliding window segmentation
Variable Illumination Color shift, over/under-exposure CLAHE contrast enhancement
H.264 Compression Logo and label degradation Lanczos4 upscaling
Background Clutter Reduced signal-to-noise ratio 2% safety margin crop
Table 3.1: Summary of video quality challenges and their mitigations.
### 3.4 ### Dataset Description and Retrieval Approach Evolution
The detection pipeline operates on two datasets: public foundation (COCO, 330K images, 80 categories)
providing broad prior knowledge, and custom domain-specific annotations for appliance detection.
25

---

CHAPTER 3. Data Understanding and Preparation
This section documents the target classes, the two-model architecture, and the critical evolution from
an initial knowledge-base approach to live web scraping.
### 3.4.1 ### Target Equipment Classes
The system detects four equipment types: refrigerators (aspect ratio 0.4–0.6, tall), microwaves (1.2–1.6,
compact), laptops (1.4–1.8, landscape), and air conditioners (2.8–4.2, wide horizontal). Each exhibits
distinct geometric characteristics that inform detection strategy and annotation discipline.
The local model (YOLOv5s) runs on CPU for fast frame screening. The cloud model (RF-DETR
via Roboflow custom-workflow-3) provides high-precision bounding boxes. Both leverage COCO
pre-training but specialize in appliance detection through domain-specific fine-tuning.
### 3.4.2 ### Evolution: Knowledge Base to Live Scraping
An initial prototype attempted to build a searchable knowledge base of appliances. The approach:
scrape product data from Tunisian e-commerce sites (Mega.tn, MyTek.tn, Tunisianet.com), structure
each product with its specifications in JSON format, embed reference images using CLIP (clip-vit-
base-patch32) into a Qdrant vector database, then embed detected field images and match them via
vector similarity to retrieve specifications.
Implementation succeeded technically. The scraping worked. Embeddings were computed. Database
queries returned results within seconds.
But the core accuracy problem was fundamental: comparing vectors of a detected appliance image
against vectors of reference images fails. A Gree air conditioner photographed in a field environment
produces a different embedding than the same Gree AC photographed for e-commerce. Viewing angle,
lighting, background — all shift the embedding. Vector matching between input (field photo) and
output (database reference) produces no good accuracy.
Beyond accuracy, the maintenance burden is insane. The Tunisian e-commerce landscape changes
constantly: new products launch, old ones disappear, specifications update. Keeping a knowledge base
current requires continuously scraping new products, re-embedding images, reindexing the database.
The volume of data is massive and constantly growing. The database becomes obsolete faster than it
can be maintained. It will always need updating, always be incomplete, always be outdated.
### 3.4.3 ### Custom Air Conditioner Dataset
COCO contains no indoor AC units. A custom dataset of 40 annotated AC images from Tunisian
residential and commercial environments was collected: apartment wall mounts, office buildings, utility
rooms. All 40 images were annotated with bounding boxes following strict standards (tight margins
≤ 5%, class purity, ≥ 320 × 320 px minimum), then uploaded to Roboflow for version control.
[PLACEHOLDER: Figure 3.4.1 — Target Class Aspect Ratio Distribution]Histogram showing
aspect ratio ranges for all 4 classes.
26

---

CHAPTER 3. Data Understanding and Preparation
[PLACEHOLDER: Figure 3.4.2 — Sample Annotated Training Images]Grid of 8 examples (2 per
class) showing tight bounding box discipline.
[PLACEHOLDER: Figure 3.4.3 — Custom AC Dataset Examples]4 representative AC annotations
from Tunisian environments.
### 3.4.4 ### From Knowledge Base to Live Pipeline
Rather than maintaining a pre-indexed knowledge base, the system pivots entirely: live web queries
per-request. When an appliance is detected, the system searches current sources (DuckDuckGo) using
detected class and extracted text, fetches live vendor pages, extracts raw specifications, and returns
current data. No pre-indexed database. No vector matching. Always accurate. Always current. The
cost is 2–3 second latency per query — acceptable for forensic workflows where accuracy is paramount.
These raw specifications fetched from live e-commerce sources then enter the data preparation pipeline
(Section 3.5), where they are algorithmically cleaned, structured, and optimized before being passed to
the multimodal reasoning system in Chapter 4.
### 3.5 ### Data Preparation Pipeline: Seven-Stage Architecture
The complete process of data preprocessing can be divided into seven processes that help eliminate any
redundancy, improve the quality of data, and reduce computational costs. Each process is performed
through predefined methods, without the involvement of any manual effort, such as converting raw
frames into forensic-friendly Hero frames.
### 3.5.1 ### Stage 1: Video Extraction and Data Expansion
Goal and Approach
The first step of the pipeline is to break down the video into separate images (frames). When a video is
recorded, it is compressed to make the file small and easy to send over mobile networks. However, to
analyze the images, we must expand the video back into its raw form.
If the entire video is loaded into the memory at once, the system would definitely crash. The trick is to
read the frames continuously so that the system has only one frame in its memory. This way, regardless
of the duration of the video, the memory usage will be kept stable.
System Workflow
To transform the video file into single images, we use OpenCV with an FFmpeg backend. The process
follows three simple steps:
27

---

CHAPTER 3. Data Understanding and Preparation
1. Compressed Video
↓ (Read frame by frame using OpenCV & FFmpeg)
2. Temporary Memory Buffer
↓ (Saved immediately as a clean image file)
3. Folder of Raw JPG Frames
• Step 1: The system opens the raw MP4 video file and reads it packet by packet using FFmpeg.
• Step 2: Every single frame is turned into an uncompressed image grid. This temporary grid
takes up exactly 1.7 MB of memory. As soon as it is processed, it is erased from memory to
make room for the next frame.
• Step 3: The frame is saved to the disk as a high-quality, lossless JPG file. The files are named in
order (frame_0001.jpg to frame_0862.jpg). Saving them as JPGs ensures we do not lose
any fine details like small text or equipment logos.
Measuring the Data Volume
To evaluate the pipeline’s efficiency across our full dataset, we tested multiple videos. To keep this
chapter clear and easy to follow, we selected one standard video sequence as a representative example
case study. The exact data measurements of this baseline transformation are shown in Table 3.2.
Metric Value Description
Video File Size 28 MB The compressed MP4 file sent from the phone
Video Length 28.92 seconds How long the video lasts
Frame Rate 30 fps Frames recorded every second
Total Frames 862 frames Total number of images extracted
Frame Resolution 576 × 1024 The pixel size of each image
Single Frame Size 1.7 MB Memory size of one raw image
Total Raw Data Size 1.5 GB Total size if we open all frames (862 × 1.7 MB)
Table 3.2: Video Extraction and Data Measurements.
As Table 3.2 shows, opening a small 28 MB video file creates a massive 1.5 GB of raw data.
Storing all of these 862 images in the memory will be quite cumbersome, considering that we will
need 1.5 GB RAM, which is not economical. In addition, uploading all of these images to the cloud
will be time-consuming and costly as well.
This first stage represents the maximum amount of data in our project (100%). It proves exactly why
we need the next six steps of the pipeline, which will filter out the repetitive images and destroy 99.2%
of this heavy data load before it ever gets sent to the cloud.
With these challenges identified, the system first applies Algorithmic Frame Budgeting to determine
which frames are worth processing at all.
28

---

CHAPTER 3. Data Understanding and Preparation
The Dynamic Sampling Mechanism
To make sure this works seamlessly across our entire dataset,where videos captured by operators come
in all different lengths the system automatically calculates a tailored skipping pattern for each video.
Instead of opening heavy picture files, our code simply counts the text names of the files. If the total
photo count for a video is higher than our maximum budget of 28, it calculates a custom skipping step
using simple division:
Skipping Step = ⌊Total Extracted Photos from Video/28⌋ (3.1)
How this works in practice across the dataset:
• For a short video: If a video yields around 28 frames, the step calculates to 1, meaning every
frame is kept.
• For a longer video: If a 2-minute walkthrough from the dataset yields 120 frames, the formula
calculates a step size of 4.
With the aid of this step value, we will easily be able to skip through this sequence of images to get
exactly 28 images (selecting one image after every four images). All those images that are not selected
will be deleted from the memory space straight away.
Operational and Computational Impact
This design gives our backend a system-wide performance breakthrough across all processed data:
• Stable Processing Speed: Because the sorting and filtering are performed entirely on lightweight
text lists rather than heavy picture grids, the system’s speed stays completely flat. A video’s
length no longer dictates how hard the server has to work.
• Low Memory Footprint: No matter the initial size or duration of the incoming video file, the
backend only ever opens those 28 final physical images using OpenCV. This boundaries our
maximum RAM usage at a tiny, safe baseline of just 49 MB (28 frames × 1.76 MB).
This makes the pipeline incredibly dependable and ready to handle hundreds of technicians uploading
completely different videos at the exact same time without slowing down or crashing the server.
### 3.5.2 ### Stage 2: Sharpness-Based Quality Analysis
After the process of time budgeting, the algorithm goes ahead to analyze motion blurring and camera
distortion through motion blur analysis using theLaplacian VarianceEdge detector. At first, every
single frame is converted into a grayscale image with only one channel using OpenCV. This makes it
possible for easy analysis of motion blur since the Laplacian edge detector uses second-order spatial
derivative to determine the edges of images. Sharp images are those with high contrast; therefore, have
29

---

CHAPTER 3. Data Understanding and Preparation
high variance values (Sframe) while blurred images have lower variance values. Mathematically, this
frame sharpness score is defined as:
Sframe = σ
2
(∇
2
I) = 
1
N
X
i,j
 
∇
2
Ii,j − μ

2 
(3.2)
Where ∇
2
Ii,j represents the discrete Laplacian value at pixel coordinate (i, j), μ is the mean of the
spatial derivatives across the frame, and N is the total pixel count.
To demonstrate this mechanism in practice, a 28 MB sample video from our dataset was utilized as an
illustrative case study, with the real-time quality metrics mapped in Figure 3.5:
Figure 3.4: Real-time sharpness analysis comparing a blurry panning sequence (Frame 42) with a
stabilized camera view (Frame 96).
As illustrated in the case study timeline in Figure 3.5, rapid mid-video camera transitions cause Frame
42 to drop to a low baseline sharpness score of 47.11. Conversely, as the operator stabilizes the lens on
a physical asset, edge definition spikes sharply, reaching a peak clarity score of 394.70 at Frame 96
(yielding an 8.4× structural contrast enhancement).
Instead of enforcing a blind cutoff threshold that risks permanently discarding rare, usable data, this
global score (Sframe) is preserved. the global score (Sframe) is stored and used as a penalty term within
the formula for creating the overall score.
30

---

CHAPTER 3. Data Understanding and Preparation
### 3.5.3 ### Stage 3:The YOLOv5s Gatekeeper and Frame Scoring
Even at this stage, after filtering by budgeting, transmitting all frames to the cloud for their analysis
would be a waste of resources and a bad idea in terms of expenses. An empty corridor and a blurry
wall do not carry any value as data for processing, but its analysis costs exactly as much as analyzing
an adequate picture of an appliance. Hence, in order to save on expenses, a local neural network acts as
a gate that analyzes every frame and filters it accordingly.
The chosen model that fits this task is YOLOv5s, which is the light-weight version of the YOLOv5
series of neural networks. The network structure optimization helps it to have a quick loading time as
well as perform nearly instant inference with a speed of about 98 ms per frame on a regular CPU.
The Two-Stage Sieve
Each budgeted frame passes through two consecutive filters before it is allowed to proceed:
1. The Neural Sieve: YOLOv5s runs local inference on the frame to generate an array of detected
bounding boxes. If no structural objects are detected—meaning the frame contains only
background noise such as plain walls, floors, or general clutter the frame is instantly discarded
from memory. No further processing occurs,and no cloud request is initialized.
2. Forensic Whitelisting: Because YOLOv5s is pre-trained on the comprehensive COCO dataset,
it naturally recognizes hundreds of object categories that are entirely irrelevant to industrial
equipment inspection (e.g., chairs, plants, cups). To prevent this environmental noise from
reaching the downstream pipeline, a strict whitelist keeps only detections belonging to the specific
target equipment families. Any frame whose detections consist entirely of non-whitelisted objects
is discarded at this stage.
The physical execution of this localized neural gatekeeper on our case study video sequence is illustrated
in Figure 3.6:
Figure 3.5: YOLOv5 local gatekeeper execution comparing an empty background sequence (left) with
a valid target appliance detection (right).
31

---

CHAPTER 3. Data Understanding and Preparation
As visually demonstrated in the case study timeline in Figure 3.6:
• Background Discarding: Frame 15 captures an early panning sequence aimed at a plain white
closet door surface. Because the local YOLOv5 engine yields zero target object arrays, the frame
is recognized as empty background noise and is instantly erased from memory.
• Whitelisting and Selection: Conversely, Frame 96 successfully isolates a target refrigerator
appliance with a localized network confidence score of 0.70.
Composite Quality Scoring
Frames that successfully survive both sieve filters are not treated equally by the pipeline. Rather than
forwarding them to the cloud indiscriminately, the system evaluates and assigns each surviving frame a
single Composite Quality Score (Q). This metric blends visual, neural, and spatial measurements
to mathematically determine how useful a given frame is likely to be for accurate downstream
identification:
Q = 0.38 · Sobj + 0.22 · Sframe + 0.22 · Cyolo + 0.10 · Dcenter + 0.08 · Abbox (3.3)
Where the metrics are defined as follows:
• Sobj represents the localized Laplacian sharpness measured directly inside the cropped equipment
bounding box (Icrop). It carries the dominant weight because a blurry crop of an appliance details
page or a serial label is the primary cause of recognition failure.
• Sframe is the global frame sharpness score computed during the Stage 2 Laplacian variance
analysis.
• Cyolo is the raw localized confidence score returned by the YOLOv5 engine.
• Dcenter represents the normalized geometric distance between the center of the object bounding
box and the true center of the frame canvas.
• Abbox is the relative area occupied by the bounding box with respect to the total pixel resolution
of the frame.
These final scores populate a ranked candidate pool, allowing the system to pick the absolute
highest-scoring keyframes to forward to the subsequent cloud detection layers.
### 3.5.4 ### Stage 4:Cloud-Based Precision Inference via Roboflow Workflows
The local YOLOv5s gatekeeper is optimized for speed, which limits its overall localization granularity.
A lightweight neural network model running exclusively on a local CPU can effectively determine
whether a frame is worth examining, but it cannot establish with absolute certainty what specific
appliance is present, isolate its exact geometric boundaries, or provide the confidence margins required
32

---

CHAPTER 3. Data Understanding and Preparation
for forensic-grade auditing. For that level of architectural precision, the pipeline escalates candidate
keyframes to the cloud infrastructure.
The system utilizes Roboflow Workflows as its core cloud computer vision inference engine. Unlike
general-purpose cloud APIs, Roboflow hosts custom-managed vision pipelines that are fine-tuned on
specialized object categories rather than generic datasets. This specialization provides significantly
higher precision where the cloud infrastructure executes models trained on extensive, high-variance
examples of the exact target equipment under diverse environmental conditions, running on dedicated
hardware acceleration rather than shared, low-power CPU threads.
Parallel Model Architecture
The structural design of the cloud workflow utilizes a multi-model ensemble approach. Rather than
relying on a single, broad-spectrum network, the pipeline executes two detection models in parallel
on every incoming frame.
rfdetr-medium represents the high precision and accuracy of general appliances detector based on
the Transformer algorithm for recognizing common appliances such as laptops and refrigerators, while
find-airconditioner is the specific model used for recognizing real air conditioning equipment. It
should be noted that a separate model is required because generic datasets cannot properly recognize
wall-mounted split ACs.
The conditional node pick_best will select the better result from either of the two bounding box
array and its corresponding confidence matrix based on maximum confidence after parallel processing,
keeping one output only. This will be further fed to two visualization layers for visualizing the bounding
boxes and labels.
The layout of this hosted cloud pipeline is illustrated in Figure 3.6:
33

---

CHAPTER 3. Data Understanding and Preparation
Figure 3.6: The Roboflow cloud workflow.
The Hero Frame Generation
The output of this cloud processing procedure is an inspection image annotated through Roboflow’s
visualization tools. The graphic has been labeled with specific colors for different categories and is
displayed as bounding boxes. The improved graphic will be used as the Hero Frame that represents
the irrefutable proof captured in the inspection log of the field operator.
An authentic operational example of this generation sequence is shown in Figure 3.7:
34

---

CHAPTER 3. Data Understanding and Preparation
Figure 3.7: A real Hero Frame output from the system: a refrigerator detected at 97.56% confidence
with a labeled bounding box rendered by the Roboflow cloud pipeline.
As illustrated in Figure 3.7, this system successfully confines a target refrigerator unit in a very high
confidence level of 97.56%, precisely capturing all the contours of the unit despite the background
being extremely cluttered. In order to ensure that data integrity is kept in check before any data can be
stored in the final reporting repository, a high confidence filter level of 60% is set for the entire process.
### 3.5.5 ### Stage 5:Final Hero Frame Selection
Following edge screening (YOLOv5s) and cloud verification (Roboflow), the system aggregates all
validated equipment hits into a unified candidate pool (global_pool). Because a single asset can
appear across multiple video frames, this selection phase deduplicates the data to yield exactly one
authoritative Hero Frame per unique equipment type—retaining the sharpest, most centered, and
highest-confidence shot.
Deduplication Logic
The selection operates through three direct steps:
1. Read Pre-Computed Scores: The system reads the quality scores (Q) directly from the pool.
Because these were computed upstream at the moment of initial detection, this phase requires
zero recalculation overhead.
2. Two-Priority Sort: The entire pool is sorted using a composite key:
35

---

CHAPTER 3. Data Understanding and Preparation
This automatically prioritizes cloud-based Roboflow detections over local edge detections due to
their superior classification precision, while sorting by the highest quality score (Q) within each
source tier.
3. Category Locking: The system iterates through the sorted list and locks the first detection
encountered per category. Any subsequent, lower-ranking candidate matching that locked
category is permanently discarded.
Output and Downstream Integration
Each winning frame is saved to disk using the naming convention hero_{rank}_{category}.png.
This file layout is illustrated in Figure 3.8:
Figure 3.8: The finalized hero frame output
Crucially, the locked category name serves as a definitive type hint for backend workflow services. By
providing a verified computer vision tag upfront, the system completely bypasses the large language
model’s initial classification reasoning loops. This eliminates one cloud API call per frame, directly
reducing processing latency and token costs. Crucially,The locked category name acts as a direct type
hint, bypassing language model classification, reducing latency, and saving token costs by eliminating
API calls.
36

---

CHAPTER 3. Data Understanding and Preparation
### 3.5.6 ### Stage 6: Enhancement — Image Preprocessing for Optical Character
### Recognition
Although this pipeline efficiently detects target equipment in the selected Hero Frame, providing the
crop bounding boxes as direct inputs for the Vision Large Language Model (VLLM) often results
in unsatisfactory text recognition outcomes. Serial numbers, model names, and energy symbols are
usually very small, lack contrast, and may be deteriorated by reflections or bad lighting. To ensure the
best possible output, an additional three-stage preprocessing pipeline is performed on the image using
the enhance_crop_for_ocr() method.
Dimensional Standardization: Lanczos4 Upscaling
Bounding boxes that are small have problems of poor resolution for deciphering alphanumeric texts. To
overcome such problems, there is a mandatory minimum resolution of 800 px for the smaller dimension,
which ensures that lower-resolution images are automatically scaled up.
In order to ensure no edge artifacts or blurring, the method uses Lanczos4 interpolation
(cv2.INTER_LANCZOS4) instead of traditional techniques which either replicate neighboring
pixels(jagged edges) or average the neighbors(blur). In contrast to the former, Lanczos4 can be
considered a smart generator of pixels since it takes into account a big window of 64 neighboring
pixels simultaneously and uses wavelets for pixel calculation.
This approach accomplishes two critical tasks for text extraction:
• Sharpness Preservation: It maintains crisp boundaries around shapes, preventing letters from
bleeding or melting into the background sticker color.
• Contrast Boosting: The algorithm naturally creates a subtle contrast enhancement directly on
the sharp borders where text meets a background surface.
This targeted reshaping ensures that upscaled alphanumeric characters appear highly defined and
legible, directly lowering downstream text extraction errors.
Local Contrast Optimization via CLAHE
Labels used in industries are often printed on reflective substrates and hence suffer from inconsistent
illumination, whereby the label is sometimes hidden under both shadows and glare. Normal global
contrast manipulation in such images does not work since the glare area gets overexposed while
increasing the noise in the background.
The pipeline improves images by applying Contrast Limited Adaptive Histogram Equalization (CLAHE)
on the luminance channel in LAB space. It splits the image into an 8x8 local grid to match contrast
in each square, brightening shadows and darkening glare. Figure 3.10: The (clipLimit=2.5) limit
preventing over-enhancement and background grain amplification.
37

---

CHAPTER 3. Data Understanding and Preparation
Figure 3.9: Visual impact of the CLAHE algorithm on localized luminance.
High-Frequency Edge Amplification
In the last stage of the optimization process, a customized unsharp mask filter is employed for sharpening
the images through high contrasts between the central pixel and the surrounding pixels. High contrasts
bring to focus fine lines that represent boundaries of characters present on the label. Fine lines help
in distinguishing characters without errors, thus reducing the likelihood of misinterpretations like
mistaking an "S" for "5" or "B" for "8".
### 3.5.7 ### Stage 7: Specification Retrieval — Web Data Cleaning via DOM Decom-
### position
Once the forensic vision model extracts the precise brand and model identifier of an appliance, the
system initiates the Specification Retrieval Phase . This step autonomously searches manufacturer
and e-commerce websites to collect missing internal technical attributes, such as technical capacities,
dimensions, or energy ratings .
However, feeding raw product webpage HTML directly into a Large Language Model (LLM) introduces
two core operational problems
• Token Exhaustion: A single product webpage can contain massive amounts of raw HTML due
to scripts, layout styling, and heavy visual code, quickly overloading the model’s text capacity.
• Contextual Noise: Webpages are cluttered with irrelevant information like promotional banners,
customer reviews, and navigation links that confuse the model and trigger data hallucinations .
38

---

CHAPTER 3. Data Understanding and Preparation
To resolve these inefficiencies, the system applies targeted Document Object Model (DOM) Decom-
position using the BeautifulSoup library to strip away the clutter before any text goes to the LLM
.
Aggressive Noise Eradication
The initial step systematically eliminates non-semantic and non-textual structural elements from the
webpage document tree. The cleaning engine strips away underlying code blocks that do not contain
core product text, including interactive buttons, styling instructions, layout headers, footers, and tracking
scripts.
By erasing these unnecessary segments along with their nested elements, the system completely
removes the background clutter of the website. This single cleaning operation routinely handles the
heaviest lifting, reducing the raw web character payload by more than 80% before it is processed further.
Heuristic Priority Extraction
After noise removal, the system does not attempt to read any further text serially from top to bottom
but makes use of structure-based heuristics in actively identifying high-priority data through the use of:
1. Tables and Definition Lists: The act of parsing extracts the data straight from the structured
HTML table and description lists. The parsing activity incorporates the inclusion of the special
separator character | so as to distinguish the attribute from the value, for instance Capacity | 380
Liters.
2. Semantic Label Matching: When technical information exists within generic text blocks, the
software will search for functional terms such as "specification," "characteristics," "details," or
"data sheets" within the description attributes and section headings. This helps to pinpoint where
the technical information is even in varying website designs.
Context Window Capping
Blocks of prioritized technical data are concatenated before anything else. In order to guarantee full
compatibility with efficient downstream models and avoid token overflow problems, the finalized clean
string is hard-capped at an optimal limit.
### 3.6 ### Conclusion
In this chapter, we can see how the architecture of the system takes raw data from vision and text and
produces high-quality input through an efficient pipeline of designs and optimization decisions. These
concepts have made possible the creation of the multimodal reasoning system introduced in Chapter 4.
39

---

# Webography
[W1] Amazon Web Services, “What is Retrieval-Augmented Generation (RAG)?” Available at:
https://aws.amazon.com/what-is/retrieval-augmented-generation/. Accessed
on May 29, 2026.
40