.PHONY: site clean

publish:
	POLLEN_RELEASE=1 raco pollen render -p
	raco pollen publish

clean:
	raco pollen reset

start:
	raco pollen start
