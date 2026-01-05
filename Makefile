posts/index.ptree: all-posts-files
	pass

.site: posts.ptree
	raco setup -p
	raco pollen render -p

