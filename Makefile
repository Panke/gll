probatsrc = subs/probat/*.d
# sadly the order matters
gllsrc = src/grammar.d src/gll.d src/data.d src/util.d
testsrc = tests/*d
main = src/main.d
testmain = tests/testmain.d
DC ?= dmd

commonflags = -Isubs
testflags = -debug -unittest -g
releaseflags = -release -O -inline -noboundscheck
devflags = -debug -g 

.PHONY: test runtest release  dev

dev: build/dev

build/dev: $(gllsrc) $(probatsrc) ${main}
	- mkdir build 2> /dev/null
	${DC} $(commonflags) $(devflags) -ofbuild/dev -odbuild $(FLAGS) ${gllsrc} ${main}

test: build/test

build/test: $(gllsrc) $(testsrc)
	- mkdir build 2> /dev/null
	${DC} -ofbuild/test -odbuild $(commonflags) $(testflags) $(FLAGS) $(gllsrc) $(testsrc) ${probatsrc}

runtest: build/test
	build/test $(P)

release: build/release

build/release: $(gllsrc) $(main)
	- mkdir build 2> /dev/null
	${DC} $(commonflags) -ofbuild/gllgen -od/build $(releaseflags) $(FLAGS) $(gllsrc) $(main)

stest: ${gllsrc} ${probatsrc} ${testmain}
	- mkdir build 2> /dev/null
	${DC} $(commonflags) $(testflags) ${FLAGS} ${gllsrc} ${testmain} ${probatsrc} tests/${T}.d -ofbuild/${T}

clean:
	rm -rf build
