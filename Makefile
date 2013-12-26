#!/usr/bin/make -f

test:
	nosetests -sv
travis:
	nosetests -s --with-coverage
	flake8 tests
