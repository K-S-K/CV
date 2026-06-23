# My AI

## Useful hints

---

### Merge Sequence

#### Step 1 - Switch to master

```bash
git checkout main
```

#### Step 2 - Actualize local master

```bash
git pull origin main
```

#### Step 3 - Get list of local branches

```bash
git branch
```

#### Step 4 - Execute merge process

```bash
git merge --no-ff 
```

Then, copy the  name of the feature branch and paste it to the end of the command.

Edit the merge message.

#### Step 5 - Switch to master

```bash
git push origin main
```

#### Step 6 - Remove the Feature branch, if it is no longer necessary

```bash
git branch -D 
```

---

### Squash Commits

#### Step 1 — See how many commits you want to squash

```bash
git log --oneline
```

The example of the result:

```bash
a1b3c7d Fix typo
e4f8a12 Update section
c2d1f22 Fix formatting
b7e81aa Add documentation header
```

Assume we want to squash the last **4 commits**.

#### Step 2 — Start interactive rebase

```bash
git rebase -i HEAD~4
```

Git will open an editor:

```bash
pick b7e81aa Add documentation header
pick c2d1f22 Fix formatting
pick e4f8a12 Update section
pick a1b3c7d Fix typo
```

Change it to:

```bash
pick b7e81aa Add documentation
squash c2d1f22 Fix formatting
squash e4f8a12 Update section
squash a1b3c7d Fix typo
```

Save and close.

#### Step 3 — Edit the final commit message

Git will ask for the new message:

```bash
Add documentation
```

Save again.

#### Step 4 — If commits were already pushed

We must force push:

```bash
git push --force
```
