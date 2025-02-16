clean:
	rm -rf ./out
	mkdir ./out

build: clean
	clang -framework Foundation -framework CoreMIDI -framework CoreGraphics -framework CoreAudio main.m -o ./out/keyset

run: build
	./out/keyset

