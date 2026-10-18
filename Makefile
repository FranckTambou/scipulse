# =====================================================================
# SciPulse — commandes du projet
#   make up        démarre toute la stack de zéro (build + init)
#   make pipeline  lance le pipeline complet Bronze -> Silver -> Gold
#   make help      liste les commandes
# =====================================================================
SHELL := /bin/bash
COMPOSE := docker compose
AF := $(COMPOSE) exec -T airflow-scheduler

.DEFAULT_GOAL := help

.PHONY: help
help: ## Affiche cette aide
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2}'

.env:
	@cp .env.example .env
	@sed -i "s/^AIRFLOW_UID=.*/AIRFLOW_UID=$$(id -u)/" .env
	@echo ".env créé à partir de .env.example (AIRFLOW_UID=$$(id -u))"

.PHONY: dirs
dirs:
	@mkdir -p logs/pipeline reports gx docs/screenshots docs/gx_data_docs
	@chmod -R a+rwX logs reports gx docs 2>/dev/null || true

.PHONY: up
up: .env dirs ## Construit et démarre toute la stack, puis initialise buckets / index / Kibana
	$(COMPOSE) up -d --build
	@echo "Attente de l'initialisation (bootstrap)..."
	@$(COMPOSE) wait bootstrap >/dev/null 2>&1 || true
	@$(COMPOSE) logs --no-log-prefix bootstrap | tail -n 25
	@$(MAKE) --no-print-directory urls

.PHONY: urls
urls: ## Affiche les URLs des interfaces
	@echo ""
	@echo "  Airflow  -> http://localhost:8080  (admin / admin)"
	@echo "  Kibana   -> http://localhost:5601"
	@echo "  MinIO    -> http://localhost:9001  (scipulse / scipulse-secret)"
	@echo "  Spark    -> http://localhost:8088"
	@echo "  ES       -> http://localhost:9200"

.PHONY: down
down: ## Arrête la stack (les données sont conservées)
	$(COMPOSE) down

.PHONY: clean
clean: ## Arrête la stack ET supprime toutes les données (volumes)
	$(COMPOSE) down -v --remove-orphans
	rm -f logs/pipeline/*.jsonl reports/*.json reports/*.txt

.PHONY: ps
ps: ## État des services
	$(COMPOSE) ps

.PHONY: logs
logs: ## Logs de tous les services (Ctrl+C pour quitter)
	$(COMPOSE) logs -f --tail=100

.PHONY: bootstrap
bootstrap: ## Rejoue l'initialisation (buckets, index, objets Kibana)
	$(COMPOSE) run --rm bootstrap

# ---------------------------------------------------------------------
# Pipeline
# ---------------------------------------------------------------------
.PHONY: unpause
unpause:
	$(AF) airflow dags unpause scipulse_hn_microbatch
	$(AF) airflow dags unpause scipulse_hn_backfill
	$(AF) airflow dags unpause scipulse_batch_pipeline

.PHONY: hn
hn: ## Ingestion HN : backfill historique Algolia + active le micro-batch toutes les 5 min
	$(AF) airflow dags unpause scipulse_hn_microbatch
	$(AF) airflow dags unpause scipulse_hn_backfill
	$(AF) airflow dags trigger scipulse_hn_backfill

.PHONY: pipeline
pipeline: ## Déclenche le DAG complet ArXiv -> Silver -> citations -> Spark -> Gold
	$(AF) airflow dags unpause scipulse_batch_pipeline
	$(AF) airflow dags trigger scipulse_batch_pipeline
	@echo "Suivi : http://localhost:8080/dags/scipulse_batch_pipeline/grid"

.PHONY: status
status: ## État des dernières exécutions de DAG
	@for d in scipulse_hn_backfill scipulse_hn_microbatch scipulse_batch_pipeline; do \
	  echo "== $$d"; $(AF) airflow dags list-runs -d $$d -o plain 2>/dev/null | head -n 4; done

.PHONY: counts
counts: ## Compte les documents de chaque index Elasticsearch
	@curl -s 'http://localhost:9200/_cat/indices/arxiv*,scipulse*?v&h=index,docs.count,store.size'

# ---------------------------------------------------------------------
# Qualité, validation, livrables
# ---------------------------------------------------------------------
.PHONY: test
test: ## Tests unitaires + test end-to-end Spark sur jeu de test (fixtures)
	$(AF) python -m pytest -q /opt/project/tests

.PHONY: validate
validate: ## Exécute les requêtes analytiques cibles sur la couche Gold
	$(AF) python /opt/project/infra/../src/scipulse/gold/validate_gold.py

.PHONY: datadocs
datadocs: ## Copie les Data Docs Great Expectations dans docs/gx_data_docs
	rm -rf docs/gx_data_docs && mkdir -p docs/gx_data_docs
	cp -r gx/uncommitted/data_docs/local_site/. docs/gx_data_docs/ 2>/dev/null || echo "Pas encore de Data Docs : lancez d'abord le pipeline."
	@echo "Ouvrir docs/gx_data_docs/index.html (ex : python -m http.server -d docs/gx_data_docs 8000)"

.PHONY: notebooks
notebooks: ## Exécute les notebooks d'analyse (sorties enregistrées dans notebooks/)
	@for nb in 01_qualite_donnees 02_pipeline_spark 03_validation 04_extension_clustering; do \
	  echo "== $$nb"; \
	  $(AF) jupyter nbconvert --to notebook --execute --inplace --ExecutePreprocessor.timeout=1800 /opt/project/notebooks/$$nb.ipynb || exit 1; \
	done

.PHONY: kibana-export
kibana-export: ## Exporte les objets Kibana (après modification manuelle des dashboards)
	$(AF) python /opt/project/infra/kibana/export_saved_objects.py

.PHONY: zip
zip: ## Construit l'archive de rendu prenom_nom_projet4_AIA01.zip
	bash scripts/make_zip.sh
