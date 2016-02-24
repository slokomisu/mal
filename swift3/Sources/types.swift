
enum MalError: ErrorType {
    case Reader(msg: String)
    case General(msg: String)
    case MalException(obj: MalVal)
}

class MutableAtom {
    var val: MalVal
    init(val: MalVal) {
        self.val = val
    }
}

enum MalVal {
    case MalNil
    case MalTrue
    case MalFalse
    case MalInt(Int)
    case MalFloat(Float)
    case MalString(String)
    case MalSymbol(String)
    case MalList(Array<MalVal>)
    case MalVector(Array<MalVal>)
    case MalHashMap(Dictionary<String,MalVal>)
    // TODO: internal MalVals are wrapped in arrays because otherwise
    // compiler throws a fault
    case MalFunc((Array<MalVal>) throws -> MalVal,
                 ast: Array<MalVal>?,
                 env: Env?,
                 params: Array<MalVal>?,
                 macro: Bool,
                 meta: Array<MalVal>?)
    case MalAtom(MutableAtom)
}

typealias MV = MalVal

// General functions

func wraptf(a: Bool) -> MalVal {
    return a ? MV.MalTrue : MV.MalFalse
}


// equality functions
func cmp_seqs(a: Array<MalVal>, _ b: Array<MalVal>) -> Bool {
    if a.count != b.count { return false }
    var idx = a.startIndex
    while idx < a.endIndex {
        if !equal_Q(a[idx], b[idx]) { return false }
        idx = idx.successor()
    }
    return true
}

func cmp_maps(a: Dictionary<String,MalVal>,
              _ b: Dictionary<String,MalVal>) -> Bool {
    if a.count != b.count { return false }
    for (k,v1) in a {
        if b[k] == nil { return false }
        if !equal_Q(v1, b[k]!) { return false }
    }
    return true
}

func equal_Q(a: MalVal, _ b: MalVal) -> Bool {
    switch (a, b) {
    case (MV.MalNil, MV.MalNil): return true
    case (MV.MalFalse, MV.MalFalse): return true
    case (MV.MalTrue, MV.MalTrue): return true
    case (MV.MalInt(let i1), MV.MalInt(let i2)): return i1 == i2
    case (MV.MalString(let s1), MV.MalString(let s2)): return s1 == s2
    case (MV.MalSymbol(let s1), MV.MalSymbol(let s2)): return s1 == s2
    case (MV.MalList(let l1), MV.MalList(let l2)):
        return cmp_seqs(l1, l2)
    case (MV.MalList(let l1), MV.MalVector(let l2)):
        return cmp_seqs(l1, l2)
    case (MV.MalVector(let l1), MV.MalList(let l2)):
        return cmp_seqs(l1, l2)
    case (MV.MalVector(let l1), MV.MalVector(let l2)):
        return cmp_seqs(l1, l2)
    case (MV.MalHashMap(let d1), MV.MalHashMap(let d2)):
        return cmp_maps(d1, d2)
    default:
        return false
    }
}

// hash-map functions

func _assoc(src: Dictionary<String,MalVal>, _ mvs: Array<MalVal>)
        throws -> Dictionary<String,MalVal> {
    var d = src
    if mvs.count % 2 != 0 {
        throw MalError.General(msg: "Odd number of args to assoc_BANG")
    }
    var pos = mvs.startIndex
    while pos < mvs.count {
        switch (mvs[pos], mvs[pos+1]) {
        case (MV.MalString(let k), let mv):
            d[k] = mv
        default:
            throw MalError.General(msg: "Invalid _assoc call")
        }
        pos += 2
    }
    return d
}

func _dissoc(src: Dictionary<String,MalVal>, _ mvs: Array<MalVal>)
        throws -> Dictionary<String,MalVal> {
    var d = src
    for mv in mvs {
        switch mv {
        case MV.MalString(let k): d.removeValueForKey(k)
        default: throw MalError.General(msg: "Invalid _dissoc call")
        }
    }
    return d
}


func hash_map(arr: Array<MalVal>) throws -> MalVal {
    let d = Dictionary<String,MalVal>();
    return MV.MalHashMap(try _assoc(d, arr))
}

// sequence functions

func _rest(a: MalVal) throws -> Array<MalVal> {
    switch a {
    case MV.MalList(let lst):
        let slc = lst[lst.startIndex.successor()..<lst.endIndex]
        return Array(slc)
    case MV.MalVector(let lst):
        let slc = lst[lst.startIndex.successor()..<lst.endIndex]
        return Array(slc)
    default:
        throw MalError.General(msg: "Invalid rest call")
    }
}

func rest(a: MalVal) throws -> MalVal {
    return MV.MalList(try _rest(a))
}

func _nth(a: MalVal, _ idx: Int) throws -> MalVal {
    switch a {
    case MV.MalList(let l): return l[l.startIndex.advancedBy(idx)]
    case MV.MalVector(let l): return l[l.startIndex.advancedBy(idx)]
    default: throw MalError.General(msg: "Invalid nth call")
    }
}