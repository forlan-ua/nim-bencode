import macros, json
import .. / bencode


const content = staticRead("test.torrent")
var res = bdecode(content)


import os

import libsha / sha1


echo "In run time: ", sha1hexdigest(content), " -> ", sha1hexdigest(res.bencode())
assert(sha1hexdigest(content) == sha1hexdigest(res.bencode()))


macro test(s: static[string]): untyped =
    let res = bdecode(s)
    
    result = nnkStmtList.newTree(
        nnkCall.newTree(
            ident("echo"),
            newLit("In compile time: "),
            newLit(sha1hexdigest(res.bencode())),
            newLit(" -> "),
            newLit(sha1hexdigest(s))
        ),
        nnkCall.newTree(
            ident("assert"),
            nnkInfix.newTree(
                ident("=="),
                newLit(sha1hexdigest(res.bencode())),
                newLit(sha1hexdigest(s))
            )
        )
    )
test(content)


echo "Test json: ", sha1hexdigest(content), " -> ", res.toJson().toBencode().bencode().sha1hexdigest()
assert(sha1hexdigest(content) == res.toJson().toBencode().bencode().sha1hexdigest())