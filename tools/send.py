#!/usr/bin/env python3
import argparse
import serial
import PIL
from PIL import Image

DEFAULT_SERIAL_DEVICE = '/dev/ttyUSB1'


def send(in_file, ser, debug):
    img = PIL.Image.open(in_file)  # Open input image
    gray = img.convert('L')  # Convert to grayscale

    with serial.Serial(ser, 115200) as f:
        f.write(b'\xAA')  # Send start byte
        # f.write(b'\x55'*(768*128))
        for y in range(gray.height):
            for x in range(gray.width // 8):
                data = 0
                for i in range(8):
                    a = (x + 1) % (gray.width // 8) if (i == 0) else x  # DIRTY FIX for verilog bug
                    if gray.getpixel((a * 8 + i, y)) > 100:
                        data += 2 ** (7 - i)
                if debug:
                    print("{0:08b} ".format(data), end='')
                else:
                    f.write(bytes([data]))
            if debug:
                print()


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument("input", help="Input image file to be sent")
    parser.add_argument("-d", "--debug", help="Print binary output to stdin", action="store_true")
    parser.add_argument("-s", "--serial", help=f"Specify serial device (default={DEFAULT_SERIAL_DEVICE})",
                        default=DEFAULT_SERIAL_DEVICE)

    args = parser.parse_args()
    send(args.input, args.serial, args.debug)
