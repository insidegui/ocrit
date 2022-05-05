# ocrit

Runs Vision's OCR on input images and outputs corresponding `txt` files for each image, or writes the recognized results to standard output.

```
USAGE: ocrit [<image-paths> ...] [--output <output>] [--language <language> ...]

ARGUMENTS:
  <image-paths>           Path or list of paths for the images

OPTIONS:
  -o, --output <output>   Path to a directory where the txt files will be
                          written to, or - for standard output (default: -)
  -l, --language <language>
                          Language code to use for the recognition, can be
                          repeated to select multiple languages
  -h, --help              Show help information.
```