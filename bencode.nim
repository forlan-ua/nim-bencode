import json, tables, strutils


const ZERO = ord('0')


type BencodeKind* = enum
    bkInt,
    bkString,
    bkList,
    bkDict


type Bencode* = ref object
    case kind*: BencodeKind:
        of bkInt:
            intVal*: int64
        of bkString:
            strVal*: string
        of bkList:
            listVal*: seq[Bencode]
        of bkDict:
            dictVal*: OrderedTable[string, Bencode]


proc len*(b: Bencode): int =
    case b.kind:
        of bkList:
            result = b.listVal.len
        of bkString:
            result = b.strVal.len
        of bkDict:
            result = b.dictVal.len
        of bkInt:
            discard


proc add*(b: Bencode, n: Bencode) =
    assert(b.kind == bkList)
    b.listVal.add(n)


proc `[]`*(b: Bencode, i: Natural): Bencode =
    assert(b.kind == bkList)
    b.listVal[i]


proc `[]=`*(b: Bencode, i: Natural, val: Bencode) =
    assert(b.kind == bkList)
    b.listVal[i] = val


proc del*(b: Bencode, i: Natural) =
    assert(b.kind == bkList)
    b.listVal.del(i)


iterator items*(b: Bencode): Bencode =
    assert(b.kind == bkList)
    for i in b.listVal:
        yield i


proc `[]`*(b: Bencode, k: string): Bencode =
    assert(b.kind == bkDict)
    b.dictVal[k]


proc `[]=`*(b: Bencode, k: string, val: Bencode) =
    assert(b.kind == bkDict)
    b.dictVal[k] = val


proc del*(b: Bencode, key: string) =
    assert(b.kind == bkDict)
    b.dictVal.del(key)


iterator pairs*(b: Bencode): (string, Bencode) =
    assert(b.kind == bkDict)
    for k, v in b.dictVal:
        yield (k, v)


proc newBInt*(val: int64 = 0): Bencode =
    Bencode(kind: bkInt, intVal: val)


proc newBString*(val: string = ""): Bencode =
    Bencode(kind: bkString, strVal: val)


proc newBList*(): Bencode =
    Bencode(kind: bkList, listVal: @[])


proc newBDict*(): Bencode =
    Bencode(kind: bkDict, dictVal: initOrderedTable[string, Bencode]())


proc toString*(b: Bencode): string =
    case b.kind:
        of bkInt:
            result = "i" & $b.intVal & "e"
        of bkString:
            result = $b.strVal.len & ":" & b.strVal
        of bkList:
            result = "l"
            for i in b.listVal:
                result.add(i.toString())
            result &= "e"
        of bkDict:
            result = "d"
            for key, value in b.dictVal:
                if key == "pieces":
                    result &= newBString(key).toString() & $(value.listVal.len * 20) & ":"
                    for i in value.listVal:
                        result &= i.strVal
                else:
                    result &= newBString(key).toString() & value.toString()
            result &= "e"


proc toJson*(b: Bencode, piecesToHex: bool = true): JsonNode =
    case b.kind:
        of bkInt:
            result = newJInt(b.intVal)
        of bkString:
            result = newJString(b.strVal)
        of bkList:
            result = newJArray()
            for i in b.listVal:
                result.add(i.toJson())
        of bkDict:
            result = newJObject()
            for key, value in b.dictVal:
                if key == "pieces":
                    result[key] = newJArray()
                    if piecesToHex:
                        for hash in value:
                            result[key].add(%hash.strVal.toHex())
                    else:
                        for hash in value:
                            result[key].add(%hash.strVal)
                else:
                    result[key] = value.toJson()


proc toBencode*(jn: JsonNode, piecesFromHex: bool = true): Bencode =
    case jn.kind:
        of JInt:
            result = newBInt(jn.getBiggestInt())
        of JString:
            result = newBString(jn.getStr())
        of JArray:
            result = newBList()
            for i in jn:
                result.add(i.toBencode())
        of JObject:
            result = newBDict()
            for key, value in jn:
                if key == "pieces":
                    result[key] = newBList()
                    if piecesFromHex:
                        for hash in value:
                            result[key].add(newBString(hash.getStr().parseHexStr()))
                    else:
                        for hash in value:
                            result[key].add(newBString(hash.getStr()))
                else:
                    result[key] = value.toBencode()
        else:
            discard


proc parseDictionary(s: string, i: var int): Bencode
proc parseList(s: string, i: var int): Bencode
proc parseString(s: string, i: var int): Bencode
proc parseInt(s: string, i: var int): Bencode


proc parsePieces(s: string, i: var int): Bencode =
    assert(s[i].isDigit())

    result = newBList()

    var len = 0
    while s[i] != ':':
        len = len * 10 + (ord(s[i]) - ZERO)
        i.inc
    i.inc

    len += i

    while i < len:
        result.add(newBString(s[i ..< i + 20]))
        i += 20


proc parseString(s: string, i: var int): Bencode =
    assert(s[i].isDigit())

    var len = 0
    while s[i] != ':':
        len = len * 10 + (ord(s[i]) - ZERO)
        i.inc

    let start = i + 1
    i = start + len

    newBString(s[start ..< i])


proc parseInt(s: string, i: var int): Bencode =
    assert(s[i] == 'i')
    i.inc

    result = newBInt()

    if s[i] == '-':
        i.inc
        while s[i] != 'e':
            result.intVal = result.intVal * 10 - (ord(s[i]) - ZERO)
            i.inc
    else:
        while s[i] != 'e':
            result.intVal = result.intVal * 10 + (ord(s[i]) - ZERO)
            i.inc

    i.inc



proc parseList(s: string, i: var int): Bencode =
    assert(s[i] == 'l')
    i.inc

    result = newBList()

    while i < s.len and s[i] != 'e':
        if s[i] == 'i':
            result.add(parseInt(s, i))
        elif s[i] == 'l':
            result.add(parseList(s, i))
        elif s[i] == 'd':
            result.add(parseDictionary(s, i))
        else:
            result.add(parseString(s, i))

    i.inc



proc parseDictionary(s: string, i: var int): Bencode =
    assert(s[i] == 'd')
    i.inc

    result = newBDict()
    
    var key: string
    
    while s[i] != 'e':
        key = parseString(s, i).strVal
        
        if key == "pieces":
            result[key] = parsePieces(s, i)
        elif s[i] == 'i':
            result[key] = parseInt(s, i)
        elif s[i] == 'l':
            result[key] = parseList(s, i)
        elif s[i] == 'd':
            result[key] = parseDictionary(s, i)
        else:
            result[key] = parseString(s, i)

    i.inc


proc bdecode*(s: string): Bencode =
    var i = 0
    result = parseDictionary(s, i)


proc bencode*(b: Bencode): string =
    result = b.toString()
