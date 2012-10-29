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
                this. _alwaysEmpty = true; // size > r.length;
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

        return _alwaysEmpty || _empty;
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
        foreach_reverse(i; 0 .. idx)
        {
            idx = i;
            tmp =_indices[idx].save;
            _indices[idx].popFront;
            if(_indices[idx] != old)
            {
                found = true;
                break;
            }
            swap(tmp, old);
        }

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
    assert(walkLength(_Subsets!(typeof(r2))(r2, 1)) == 3);
    assert(walkLength(_Subsets!(typeof(r2))(r2, 2)) == 3);

    int[] arr2 = [];
    auto r3 = _Subsets!(int[])(arr2, 1);
    assert(walkLength(r3) == 0);

    range = _Subsets!(int[])(arr, 10);
    assert(walkLength(range) == 0);
}


