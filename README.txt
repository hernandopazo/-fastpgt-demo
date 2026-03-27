README

FastPGT — 
=================================================

Author: Hernán Dopazo
Project: 2PQ (Precision & Quick Genomics)


DESCRIPTION
-----------

This project implements a comprehensive economic model for FastPGT (Preimplantation Genetic Testing using Oxford Nanopore sequencing), integrating:

- Analytical cost modeling
- Simulation-based scenarios
- Interactive Shiny application for real-time exploration

The objective is to estimate cost per embryo under different operational strategies, including:

- Number of samples per run
- Flow cell reuse (wash cycles)
- Batching vs rapid execution strategies


PROJECT STRUCTURE
-----------------

FastPGT/

- index.qmd                     → Main document (model + explanation)
- _quarto.yml                  → Quarto configuration
- FastPGT_app/                 → Interactive Shiny application
    └── app.R

- inputs/                      → Input data (if applicable)
- outputs/                     → Generated outputs
- figures/                     → Figures and plots

- appendix-*.qmd               → Technical and simulation appendices

- styles.css                   → Custom styling
- ONT-PGT.bib                  → Bibliography
- nature.csl                   → Citation style

- fastpgt.html                → Rendered output (if present)


REQUIREMENTS
------------

- R (>= 4.x)
- Required packages:

    shiny
    tidyverse
    DT
    quarto (recommended)

Install missing packages with:

    install.packages(c("shiny", "tidyverse", "DT"))


RUNNING THE INTERACTIVE APP
---------------------------

From any terminal location:

    cd ~/Documents/2pq/FastPGT && R -e "shiny::runApp('FastPGT_app', launch.browser=TRUE)"

This will:

- Start a local Shiny server
- Automatically open the application in your browser


RENDERING THE DOCUMENT
---------------------

To render the Quarto project:

    quarto render

Outputs will be generated in the project directory or _site/.


KEY FEATURES
------------

- Explicit cost model per run:

    C_run = n * C_WGA + C_lib + (C_FC / k) + (C_wash / k)

- Flow cell reuse modeling (k runs per FC)
- Scenario simulation across different batch sizes
- Interactive exploration via Shiny interface

- Designed for:
    - Clinical decision support
    - Operational planning
    - Economic evaluation
    - Strategic discussions (labs, IVF centers, pharma)


NOTES
-----

- The model assumes shallow WGS CNV detection workflows
- Costs can be adapted to local pricing and supplier conditions
- Flow cell reuse assumptions are configurable


LICENSE / USAGE
---------------

For research and evaluation purposes.
Contact author for collaboration or commercial use.


CONTACT
-------

Hernán Dopazo
2PQ — Precision & Quick Genomics




zip -r FastPGT_site.zip _site

Bash
quarto render

git add .    
git commit -m "test deploy"
git push

https://2pq-fastpgt.netlify.app

  