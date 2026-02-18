PAPER    = qubes-claw
DEMO     = ../demo
DOCS     = $(HOME)/Documents/qubes-claw

.PHONY: all paper diagrams posts sync clean

all: paper diagrams posts sync

paper: $(PAPER).pdf

$(PAPER).pdf: $(PAPER).tex
	pdflatex -interaction=nonstopmode $(PAPER).tex
	pdflatex -interaction=nonstopmode $(PAPER).tex

diagrams:
	python3 $(DEMO)/generate-diagrams.py $(DEMO)/

posts:
	python3 $(DEMO)/generate-posts.py $(DEMO)/ $(DEMO)/ $(DOCS)/posts/ all

sync: $(PAPER).pdf
	mkdir -p $(DOCS)/diagrams $(DOCS)/posts
	cp $(PAPER).pdf $(PAPER).tex posts.md blog-qubes-claw.md $(DOCS)/
	cp $(DEMO)/architecture.png $(DEMO)/persistence.png $(DEMO)/security.png $(DOCS)/diagrams/

clean:
	rm -f $(PAPER).aux $(PAPER).log $(PAPER).out $(PAPER).pdf

help:
	@echo "Targets:"
	@echo "  all       - Build everything and sync to ~/Documents"
	@echo "  paper     - Compile LaTeX (two passes for refs)"
	@echo "  diagrams  - Regenerate PNG architecture diagrams"
	@echo "  posts     - Regenerate social media card PNGs"
	@echo "  sync      - Copy all outputs to ~/Documents/qubes-claw/"
	@echo "  clean     - Remove LaTeX build artifacts"
