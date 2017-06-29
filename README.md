# Parscit Fork

## Clean CRFPP submodule

This is a fork of ParsCit. ParsCit ships with an older version of `crfpp` which is
hard to compile from source. In this fork, we are instead using `crfpp` as a
[submodule](https://github.com/taku910/crfpp). Also: We offer a
[Makefile](Makefile) that builds `crfpp` from source.

## Parscit wrapper for reference resolution

As work in progress, we aim to build a wrapper around ParsCit that allows reference resolution.
