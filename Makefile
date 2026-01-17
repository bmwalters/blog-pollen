.PHONY: site

site:
	raco setup -p
	raco pollen render -p

