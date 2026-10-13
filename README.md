# codex-image pour Claude Cowork

**Donnez à Claude (l'app desktop, mode Cowork) la capacité de créer des images dans ses tâches et ses automatisations, avec votre abonnement ChatGPT, sur votre Mac.**

[English version](README.en.md)

## Pourquoi Cowork, et pas Claude Code

Pour Claude Code, la génération d'images via Codex existe déjà ([codex-imagegen de JunSeo99](https://github.com/JunSeo99/claude-skill-codex-imagegen)) : Claude Code tourne sur votre Mac et lance Codex directement.

Dans l'app Claude (Cowork), c'est différent. Claude travaille dans le cloud : il ne voit pas votre Mac, ne peut pas lancer Codex, et ses tâches planifiées tournent sans vous. Résultat, dès qu'une automatisation avait besoin d'une image (couverture d'article, visuel de post, illustration de newsletter), il fallait repasser par un humain : ouvrir un autre outil, retaper un prompt, télécharger le fichier, le redonner à Claude.

Ce dépôt fait le pont. Depuis le cloud, Claude pilote votre Mac via l'extension « Control your Mac », lance Codex, attend l'image, la récupère par le dossier partagé, la contrôle et l'utilise dans la suite de la tâche. Sans vous, y compris dans une tâche planifiée qui tourne la nuit.

Concrètement, ce qui a été ajouté pour que ça marche depuis Cowork :
- une commande unique (`codex-image`) aux réponses JSON, appelable par AppleScript ;
- une attente découpée en tranches de 25 s maximum, la limite d'un appel « Control your Mac » ;
- des briefs passés par fichier, sans guillemets ni antislash qui casseraient AppleScript ;
- le retour de l'image dans la conversation par le dossier partagé ;
- un mode autonome pour les tâches planifiées (pas de question, un seul essai de retouche, rapport du chemin) ;
- le choix automatique de la bonne version de Codex, car le PATH vu par AppleScript n'est pas celui de votre Terminal.

Claude Code peut aussi l'utiliser (le skill sait lancer la commande en direct), mais ce n'est pas sa raison d'être.

<p align="center"><img src="assets/example.jpg" width="360" alt="Image générée de bout en bout par Claude via codex-image"></p>

```
Claude dans le cloud (conversation ou tâche planifiée Cowork)
   │  écrit le brief, pilote le Mac via « Control your Mac »
   ▼
Votre Mac ── codex-image ── Codex CLI ── votre abonnement ChatGPT
   │  image PNG + JPEG dans ~/Desktop/codex-images
   ▼
Claude récupère l'image par le dossier partagé, la contrôle et l'utilise (article, post, mail…)
```

## Ce qu'il faut

- Un **Mac** (Apple Silicon ou Intel).
- Un **abonnement ChatGPT**. L'abonnement de base (environ 6 $ par mois) suffit, c'est ce qui a été testé. Pas de clé API, pas de facturation à l'image. Les quotas d'images dépendent de votre formule et le prix varie selon le pays.
- **L'app Claude desktop** (Cowork) ouverte sur le Mac, avec l'extension « Control your Mac » activée. Claude Code fonctionne aussi, en bonus.
- Environ **2 Go libres** sur le disque.

Le script d'installation vérifie et installe le reste : Command Line Tools, Python 3.9+, Node 18+, Codex CLI 0.153.4+.

## Installation

### 1. Récupérer le dépôt

```bash
git clone https://github.com/ChrisLefevre/codex-image-for-claude-cowork.git
cd codex-image-for-claude-cowork
```

### 2. Vérifier puis installer

```bash
scripts/doctor.sh      # diagnostic seul, ne modifie rien
scripts/install.sh     # installe ce qui manque, en demandant avant chaque étape
```

Le diagnostic contrôle : macOS, espace disque, Command Line Tools, Python, Node, version de Codex, connexion Codex à ChatGPT, skill `codex-imagegen`, correctif Codex 0.162, dossier de sortie.

Il repère aussi le piège le plus courant : **une vieille version de Codex (souvent Homebrew) placée avant la bonne dans le PATH**. codex-image choisit toujours la version la plus récente trouvée, quel que soit l'ordre du PATH.

L'installation :
1. installe Node et Codex CLI si besoin (`npm install -g @openai/codex@latest`) ;
2. lance `codex login` (connexion avec votre compte ChatGPT dans le navigateur) ;
3. installe le skill [codex-imagegen de JunSeo99](https://github.com/JunSeo99/claude-skill-codex-imagegen) (licence MIT) ;
4. applique le correctif de compatibilité Codex 0.162 (voir plus bas) ;
5. installe la commande `~/.codex-image/bin/codex-image` et sa configuration ;
6. copie le skill `codex-image` dans `~/.claude/skills` pour Claude Code.

Option : `scripts/install.sh --output ~/Pictures/codex-images` pour changer le dossier des images (par défaut `~/Desktop/codex-images`).

### 3. Ajouter le skill dans l'app Claude

Importez `dist/codex-image.zip` dans les réglages des skills de l'app Claude. C'est l'étape qui rend la génération d'images disponible dans toutes vos conversations et tâches Cowork. (Pour Claude Code, l'installateur l'a déjà copié dans `~/.claude/skills`.)

### 4. Partager le dossier des images avec Claude

Dans l'app Claude desktop, ajoutez le dossier `~/Desktop/codex-images` à la conversation ou à la tâche (bouton « + », « Add folder »). Sans ça, Claude génère l'image mais ne peut pas la relire pour la contrôler ou la réutiliser.

### 5. Tester

```bash
echo "A red apple on a white table, square 1:1. No text." | ~/.codex-image/bin/codex-image generate - --name test
~/.codex-image/bin/codex-image wait ~/Desktop/codex-images/<date>-test
~/.codex-image/bin/codex-image finish ~/Desktop/codex-images/<date>-test pomme --open
```

Puis dans Claude : « Génère une image carrée d'un chat qui lit le journal ».

## La commande codex-image

Toutes les sous-commandes répondent en JSON, pour qu'une automatisation puisse lire le résultat.

| Commande | Rôle |
|---|---|
| `codex-image generate BRIEF \| - [--name slug] [--image ref.png] [--plan plan.json]` | Lance la génération en arrière-plan, renvoie `out_dir` |
| `codex-image wait DIR [secondes]` | Attend (25 s maximum) puis donne l'état |
| `codex-image status DIR` | État du travail, sans appeler Codex |
| `codex-image finish DIR [nom] [--open]` | Crée le JPEG, renvoie chemins et dimensions |
| `codex-image doctor [--json]` | Diagnostic complet |

`--image` sert à retoucher une image existante ou à garder la ressemblance d'une personne à partir de sa photo. `--plan` produit plusieurs pistes en parallèle.

## Dans une automatisation

Exemples de consignes pour une tâche planifiée Cowork dans [examples/automations.md](examples/automations.md) : couverture d'article de newsletter, visuel LinkedIn hebdomadaire, déclinaisons produit.

Règles du skill en mode autonome : pas de question, une idée forte, une image, contrôle visuel, une seule retouche au maximum, chemin du fichier noté dans le rapport. Si Codex échoue (Mac en veille, connexion expirée, quota atteint), la tâche continue sans l'image et le signale.

## Le correctif Codex 0.162

À partir de Codex CLI 0.162, Codex ne renvoie plus toujours le chemin de l'image dans sa réponse structurée. L'image est bien créée, mais le script d'origine échoue et la perd. Le correctif (`patches/codex-cli-0.162.patch`) retrouve le PNG apparu pendant l'exécution, en vérifiant qu'il se trouve dans le dossier de Codex, que c'est un vrai PNG et qu'il est postérieur au lancement. Limite : lancer les lots en séquence (`--workers 1`) si plusieurs générations tournent en même temps.

Si le dépôt d'origine corrige le problème, l'installateur le détecte et n'applique rien.

## En cas de souci

- **« Operation not permitted » quand Claude pilote le Mac** : macOS protège le Bureau, les Documents et les Téléchargements. Autorisez l'app Claude dans Réglages Système, Confidentialité et sécurité, Fichiers et dossiers (ou Accès complet au disque), ou choisissez un dossier de sortie hors de ces emplacements avec `--output`.
- **« codex did not return an existing PNG »** : le correctif 0.162 n'est pas appliqué. Relancez `scripts/install.sh`.
- **Codex trop vieux alors que vous venez de le mettre à jour** : deux installations coexistent (Homebrew et npm). `scripts/doctor.sh` indique laquelle est utilisée.
- **La génération échoue** : lisez `<dossier>/run/worker.log`. Souvent : connexion expirée (`codex login`) ou quota de l'abonnement atteint.

## Limites

- **Mac uniquement** pour l'instant.
- Le pilotage depuis le cloud passe par l'extension « Control your Mac » de l'app Claude desktop : l'app doit être ouverte et le Mac allumé. Ces fonctions de Claude peuvent évoluer.
- Le modèle d'image est géré par Codex : on ne peut ni le choisir ni garantir une résolution (environ 1254 × 1254 en carré lors des tests).
- Respectez les règles d'OpenAI et le droit à l'image : pas de marque, pas de personnage protégé, pas de personne réelle sans son accord.

## Désinstaller

```bash
rm -rf ~/.codex-image ~/.claude/skills/codex-image /usr/local/bin/codex-image
# Optionnel : ~/.agents/skills/codex-imagegen et ~/.claude/skills/codex-imagegen
```

## Crédits

- Génération : [Codex CLI](https://github.com/openai/codex) d'OpenAI.
- Lanceur d'images : [claude-skill-codex-imagegen](https://github.com/JunSeo99/claude-skill-codex-imagegen) de JunSeo99, licence MIT.
- codex-image (pilotage par Claude, diagnostic, installateur, correctif 0.162) : Chris Lefevre, licence MIT.

Projet indépendant, sans lien avec Anthropic ni OpenAI.
