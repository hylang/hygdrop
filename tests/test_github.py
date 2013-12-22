#!/usr/bin/env python

from hy.importer import import_file_to_module

g = import_file_to_module("github", "hygdrop/github.hy")

def test_get_github_issue():
    expected = " ".join(["Pull Request #" + "310", "on", "hylang/hy", "by",
                         "sbp:", "Library based macroexpand and macroexpand-1",
                         "(open)", "<https://github.com/hylang/hy/pull/310>",])
    actual = g.get_github_issue(None, None, "310", dry_run=True)
    assert expected == actual

def test_get_github_commit():
    expected = " ".join(["Commit", "3e8941c", "on", "hylang/hy", "by",
                         "Berker Peksag:",
                         "Convert stdout and stderr to UTF-8 properly in the run_cmd helper.",
                         "<https://github.com/hylang/hy/commit/3e8941cdde01635890db524c4789f0640fe665c3>"])
    actual = g.get_github_commit(None, None, "3e8941c", dry_run=True )
    assert expected == actual

def test_get_core_members():
    expected = "\n".join(["Core Team consists of", "Julien Danjou",
                          "Morten Linderud", "J Kenneth King", "Gergely Nagy",
                          "Abhishek L", "Christopher Allan Webber",
                          "Konrad Hinsen","Will Kahn-Greene",
                          "Paul Tagliamonte","Nicolas Dandrimont", 
                          "Berker Peksag", ])
    actual = g.get_core_members(None, None, dry_run=True)
    print(actual)
    assert actual == expected
