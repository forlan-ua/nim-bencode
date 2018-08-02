One more Bencode implementation
===============================


## Instalation
### Nim package manager

```bash
nimble install https://github.com/forlan-ua/nim-bencode
```

### Clone git repo

```bash
git clone https://github.com/forlan-ua/nim-bencode
cd nim-bencode
nimble develop
```

## Usage
### Decode/encode bencoded string

```
import bencode
const content = staticRead("test.torrent")
let bdecoded = content.bdecode()
let bencoded = bdecoded.bencode()
let bstring = bdecoded.toString()
```

### Get json from bencode

```
import bencode
const content = staticRead("test.torrent")
let bdecoded = content.bdecode()
let bjson1 = bdecoded.toJson() # Pieces will be converted to hex
let bjson2 = bdecoded.toJson(piecesToHex=false) # Pieces will be added as is
```