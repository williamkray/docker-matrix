#!/bin/bash

git branch --set-upstream git@github.com:williamkray/docker-matrix.git

git fetch upstream

git checkout main

git rebase upstream/main

git add .

git commit -m "rebasing from upstream"

git push
