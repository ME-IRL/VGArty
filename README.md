# VGArty
VGA on the Arty A7 via UART serial

This project uses the [fusesoc](https://github.com/olofk/fusesoc) and vivado, so follow the steps there to install

### Build and flash FPGA Verilog source
```sh
fusesoc --cores-root . run meirlabs::vgarty
```

### Send image
The code present in this repository is configured for 1024x768 images  
There are some test images prsent in the `tools/` directory  
```sh
pip -r tools/requirements.txt # installs dependencies (PIL and PySerial)
tools/send.py tools/test_image.bmp
```

See `tools/send.py -h` for more options

The initial image displayed is in `mem/image.mem` and was created by running:
```sh
tools/send.py tools/hello_world.bmp -d > mem/image.mem
```

### TODO
There's a bug in the verilog code where the 0th pixel (least significant bit from pixel data) is displayed from the next byte.  
The fix currently is done via the upload script where it would just send the 0th bit from the next byte instead of the current byte.  
