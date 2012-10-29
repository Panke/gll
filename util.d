/**
 * helper functions for gll.d
 */

import std.range, std.algorithm, std.stdio;



private struct _Subsets(Range, bool safe=true)
    if(isForwardRange!Range)
{
    alias ElementType!Range E;

    Range[] _indices;
    bool _empty = false;
    bool _alwaysEmpty = false;
    //E[] result;

    this(Range r, size_t size)
    {
        _indices.length = size;
        foreach(i; 0..size)
        {
            _indices[i] = r.save;
            if(r.empty)
            {
                _alwaysEmpty = true; // size > r.length;
                break;
            }
            r.popFront;
        }
    }

    @property
    E[] front()
    {
        static if(safe)
            return map!(x => x.front)(_indices).array;
        else
            return map!(x => x.front)(_indices);
    }

    @property
    bool empty()
    {
        return _empty || _alwaysEmpty || _indices[$-1] == _indices[$-2];
    }


    @property
    void popFront() { _empty = _popFront(); }

    bool _popFront()
    {
        auto old = _indices[$-1].save;
        auto tmp = _indices[$-1].save;

        _indices[$-1].popFront;
        if(!(_indices[$-1].empty))
            return false; // not empty

        bool found = false;
        // assumption: _indices.length >= 2
        size_t idx = _indices.length - 1;
        do {
            idx--;
            tmp =_indices[idx].save;
            _indices[idx].popFront;
            if(_indices[idx] != old)
            {
                found = true;
                break;
            }
            swap(tmp, old);
        } while(idx != 0);
        if(!found)
            return true; //empty now

        // adjust the bigger idx's
        old = _indices[idx].save;
        foreach(i; iota(idx+1, _indices.length))
        {
            old.popFront;
            _indices[i] = old.save;
        }
        return false; // not empty
    }
}

unittest
{
    int[] arr = [1, 2, 3, 4 ,5 ,6];
    auto range = _Subsets!(int[])(arr, 4);
    assert(walkLength(range) == 15);

    auto r2 = arr.filter!("a % 2 == 0");
    foreach(e; _Subsets!(typeof(r2))(r2, 1))
        writeln(e);
}

void main() {}

