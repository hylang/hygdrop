#!/usr/bin/env python

import os
plugin_to_load = os.path.join(os.path.dirname(os.path.realpath(__file__)),
                              "../plugins/codeeval.hy")

from hy.importer import import_file_to_module

g = import_file_to_module("codeeval", plugin_to_load)


def test_eval_code():
    expected = "[2, 2, 2, 4, 6, 10, 16, 26, 42, 68]"
    actual = g.eval_code(None, None,
                         "(defn fib [x] (if (<= x 2) 2 (+ (fib (- x 1)) (fib (- x 2))))) (list-comp (fib x) [x (range 10)])",
                         dry_run=True)

    # strip the space resulting from eval_code function
    assert actual.strip() == expected.strip()


def test_source_code():
    expected = "def fib(x):\n    return (2 if (x <= 2) else (fib((x - 1)) + fib((x - 2))))\nprint([fib(x) for x in range(10)])"
    actual = g.source_code(None, None,
                           "(defn fib [x] (if (<= x 2) 2 (+ (fib (- x 1)) (fib (- x 2))))) (print (list-comp (fib x) [x (range 10)]))",
                           dry_run=True)
    assert actual == expected
