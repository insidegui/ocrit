# ocrit

Runs Vision's OCR on input images or PDF files and outputs corresponding `txt` files for each image, or writes the recognized results to standard output.

```
USAGE: ocrit [<image-paths> ...] [--output <output>] [--language <language> ...] [--fast]

ARGUMENTS:
  <image-paths>           Path or list of paths for the images

OPTIONS:
  -o, --output <output>   Path to a directory where the txt files will be written to, or - for standard output (default: -)
  -l, --language <language>
                          Language code to use for the recognition, can be repeated to select multiple languages
  -f, --fast              Uses an OCR algorithm that prioritizes speed over accuracy
  -h, --help              Show help information.
```

## Language Selection

The `--language` (or `-l`) option can be used to indicate which language or languages will be used for OCR.

Multiple languages can be specified by repeating the option, example:

```
ocrit path/to/image.png -l ko-KR -l en-US
```

The order of the languages is important, as Vision's OCR engine will attempt to perform OCR using the languages in order. In my experience, if you have an image or document that contains a mix of English and some other language, it's best to specify `en-US` as the **last** language on the list.

### Supported Languages

Language support varies with the version of macOS and whether or not the `--fast` flag is specified.

This is the current list of supported languages as of macOS 14.4:

```
en-US, fr-FR, it-IT, de-DE, es-ES, pt-BR, zh-Hans, zh-Hant, yue-Hans, yue-Hant, ko-KR, ja-JP, ru-RU, uk-UA, th-TH, vi-VT
```

This is the current list of supported languages as of macOS 14.4, with the `--fast` flag enabled:

```
en-US, fr-FR, it-IT, de-DE, es-ES, pt-BR
```