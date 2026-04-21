import re

desc_text = "Climatiseur Samsung Inverter - Puissance 12 000 BTU - Chaud & amp; Froid - Capacité en refroidissement 12000 (BTU/h) - avec Technologie WindFree - Contrôle Wi-Fi - Niveau sonore (unité intérieure /unité extérieure) 39/46 dBA -  Circulation d'air (refroidissement, m3 / min) 10.7 - Easy Filter Plus - Nettoyage automatique - Refroidissement automatique intelligent - Minuterie 24 heures - Contrôle automatique de la direction de l'air haut / bas - Mode Sommeil paisible - Déshumidification - Dimension Unité Intérieure 820 x 299 x 215 mm- Dimension Unité Extérieure 720 x 548 x 265 mm - Poids 9.2 Kg - Garantie 5 ans"
desc_text = desc_text.lower()

pattern = r"([0-9.]+\s*[x×]\s*[0-9.]+\s*[x×]\s*[0-9.]+\s*mm)"
matches = re.findall(pattern, desc_text)
print(f"Matches found: {matches}")
