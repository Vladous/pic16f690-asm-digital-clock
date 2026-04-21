ASM=gpasm
SRC=src/main.asm
OUT=build/main.hex

all: $(OUT)

$(OUT): $(SRC)
	@mkdir -p build
	$(ASM) -p16f690 -o $(OUT) $(SRC)

clean:
	rm -rf build
