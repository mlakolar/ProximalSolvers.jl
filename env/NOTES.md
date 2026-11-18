# Run notes (issue #353)
- PS master audited: dac9f4b6819d9321117ee3cf3549e9e46a043f01 (worktree ../ps-353, branch research/issue-353)
- PB pin in PS Project.toml [sources]: a19c59aa723d085d5d7cf5242895bda16eb77214, tree 138929aa27c6221284ee1763e66b1110dd6ec418
- Loaded PB (<DEPOT>/packages/ProximalBase/2welE) src is byte-identical to the pin export (diff -rq clean), Julia 1.10.13 and 1.13.4
- PB master at audit time: 13891ccfd5c33a042c5df82d670abf1f2d786a0f (pin + 2 commits: #976 rename, #977 kkt stage B)
- PB sources are plain `git archive` exports under this run dir (pb-pin-a19c59aa, pb-master-13891ccf): two PB git worktrees created first were deleted within minutes by a concurrent session's PB worktree cleanup.
- PS #350 (weighted lasso) OPEN/draft at 65f7004; touches src/cd/leastsquares.jl, src/cd/solver.jl, src/solvers/{pgd,apg}.jl, src/utils.jl
- PS #357 (NormLinf), #355 (sqrt example), #356 (docs) open drafts
