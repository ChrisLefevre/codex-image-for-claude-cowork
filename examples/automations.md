# Exemples d'automatisations

Consignes à coller dans une tâche planifiée Claude (app desktop, Mac relié, dossier `~/Desktop/codex-images` partagé avec la tâche, skill `codex-image` installé).

## Couverture d'article chaque semaine

> Chaque lundi à 7 h : rédige l'article de la semaine sur le sujet le plus marquant de la veille IA. Avec le skill codex-image, crée une image de couverture 16:9 qui porte l'idée principale de l'article (une métaphore visuelle, pas une illustration littérale). Contrôle l'image, puis enregistre l'article et le chemin de l'image dans le rapport final.

## Visuel LinkedIn

> Chaque mardi et jeudi : à partir du dernier article publié, rédige un post LinkedIn et crée un visuel 4:5 avec codex-image. Pas de texte dans l'image. Mets le post et le visuel en brouillon et envoie-moi un récapitulatif.

## Déclinaisons produit

> Pour chaque nouveau produit ajouté cette semaine dans le catalogue, lance un plan codex-image de 3 pistes (photo studio, mise en situation, composition graphique) en 1:1. Garde la meilleure piste par produit, explique ton choix en une ligne, et dépose les JPEG dans le dossier partagé.

## Avec une photo de référence

> Crée une image carrée de moi au milieu de robots, en passant ma photo ~/Desktop/codex-images/refs/moi.png comme référence d'identité.

Commande équivalente :

```bash
~/.codex-image/bin/codex-image generate brief.txt --name moi-robots --image ~/Desktop/codex-images/refs/moi.png
```
