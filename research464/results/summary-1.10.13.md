| rule | solves | converged | converged, excess > 1e-3 | converged, above target | v0 stopped on target, rule did not converge | decision = v0 | total iterations |
|---|---|---|---|---|---|---|---|
| v0 | 206 | 173 | 12 | 61 | 0 | 206 | 5400 |
| v1 | 204 | 139 | 4 | 11 | 29 | 93 | 8176 |
| v2 | 204 | 150 | 4 | 30 | 18 | 130 | 7861 |
| v3 | 204 | 139 | 4 | 11 | 29 | 93 | 8176 |
| gv1 | 2 | 2 | 0 | 0 | 0 | 1 | 8 |

| case | T | solver | start | v0: conv/iter/excess | v1: conv/iter/excess | v2: conv/iter/excess | v3: conv/iter/excess |
|---|---|---|---|---|---|---|---|
| A1 logistic B4 | 64 | PGD | zero | T/1/5.8e-03 | T/6/2.4e-11 | T/6/2.4e-11 | T/6/2.4e-11 |
| A2 LS one free | 64 | PGD | zero | T/1/2.6e-32 | T/1/2.6e-32 | T/1/2.6e-32 | T/1/2.6e-32 |
| A2 LS one free | 64 | APG | zero | T/1/9.3e-01 | T/7/5.8e-11 | T/7/5.8e-11 | T/7/5.8e-11 |
| A3 LS two free | 64 | PGD | zero | T/1/2.3e+00 | T/196/5.9e-08 | T/196/5.9e-08 | T/196/5.9e-08 |
| A3 LS two free | 64 | APG | zero | T/1/5.3e-01 | T/45/3.9e-08 | T/45/3.9e-08 | T/45/3.9e-08 |
| B zero column W=1.0 | 64 | PGD | zero | T/30/5.3e-10 | T/30/5.3e-10 | T/30/5.3e-10 | T/30/5.3e-10 |
| B zero column W=1.0 | 64 | APG | zero | T/19/2.3e-10 | T/19/2.3e-10 | T/19/2.3e-10 | T/19/2.3e-10 |
| B zero column W=1000.0 | 64 | PGD | zero | T/19/1.0e-06 | T/30/5.3e-10 | T/19/1.0e-06 | T/30/5.3e-10 |
| B zero column W=1000.0 | 64 | APG | zero | T/14/1.1e-06 | T/19/2.3e-10 | T/14/1.1e-06 | T/19/2.3e-10 |
| B zero column W=1.0e6 | 64 | PGD | zero | T/19/1.0e-06 | T/30/5.3e-10 | T/19/1.0e-06 | T/30/5.3e-10 |
| B zero column W=1.0e6 | 64 | APG | zero | T/14/1.1e-06 | T/19/2.3e-10 | T/14/1.1e-06 | T/19/2.3e-10 |
| B zero column W=1.0e12 | 64 | PGD | zero | T/19/1.0e-06 | T/30/5.3e-10 | T/19/1.0e-06 | T/30/5.3e-10 |
| B zero column W=1.0e12 | 64 | APG | zero | T/14/1.1e-06 | T/19/2.3e-10 | T/14/1.1e-06 | T/19/2.3e-10 |
| B zero column W=1.0e100 | 64 | PGD | zero | T/19/1.0e-06 | T/30/5.3e-10 | T/19/1.0e-06 | T/30/5.3e-10 |
| B zero column W=1.0e100 | 64 | APG | zero | T/14/1.1e-06 | T/19/2.3e-10 | T/14/1.1e-06 | T/19/2.3e-10 |
| B reduced (no zero column) | 64 | PGD | zero | T/30/5.3e-10 | T/30/5.3e-10 | T/30/5.3e-10 | T/30/5.3e-10 |
| B reduced (no zero column) | 64 | APG | zero | T/19/2.3e-10 | T/19/2.3e-10 | T/19/2.3e-10 | T/19/2.3e-10 |
| C excluded column W=1.0 | 64 | PGD | zero | T/30/5.3e-10 | T/30/5.3e-10 | T/30/5.3e-10 | T/30/5.3e-10 |
| C excluded column W=1.0 | 64 | APG | zero | T/19/2.3e-10 | T/19/2.3e-10 | T/19/2.3e-10 | T/19/2.3e-10 |
| C excluded column W=1000.0 | 64 | PGD | zero | T/19/8.0e-07 | T/29/5.4e-10 | T/19/8.0e-07 | T/29/5.4e-10 |
| C excluded column W=1000.0 | 64 | APG | zero | T/14/8.6e-08 | T/18/1.3e-10 | T/14/8.6e-08 | T/18/1.3e-10 |
| C excluded column W=1.0e6 | 64 | PGD | zero | T/19/8.0e-07 | T/29/5.4e-10 | T/19/8.0e-07 | T/29/5.4e-10 |
| C excluded column W=1.0e6 | 64 | APG | zero | T/14/8.6e-08 | T/18/1.3e-10 | T/14/8.6e-08 | T/18/1.3e-10 |
| C excluded column W=1.0e12 | 64 | PGD | zero | T/19/8.0e-07 | T/29/5.4e-10 | T/19/8.0e-07 | T/29/5.4e-10 |
| C excluded column W=1.0e12 | 64 | APG | zero | T/14/8.6e-08 | T/18/1.3e-10 | T/14/8.6e-08 | T/18/1.3e-10 |
| C excluded column W=1.0e100 | 64 | PGD | zero | T/19/8.0e-07 | T/29/5.4e-10 | T/19/8.0e-07 | T/29/5.4e-10 |
| C excluded column W=1.0e100 | 64 | APG | zero | T/14/8.6e-08 | T/18/1.3e-10 | T/14/8.6e-08 | T/18/1.3e-10 |
| D free first, W=1.0 | 64 | PGD | zero | T/32/1.3e-09 | T/32/1.3e-09 | T/32/1.3e-09 | T/32/1.3e-09 |
| D free first, W=1.0 | 64 | APG | zero | T/18/1.9e-10 | T/18/1.9e-10 | T/18/1.9e-10 | T/18/1.9e-10 |
| D free first, W=1000.0 | 64 | PGD | zero | T/20/1.3e-06 | T/31/7.1e-10 | T/29/2.4e-09 | T/31/7.1e-10 |
| D free first, W=1000.0 | 64 | APG | zero | T/14/1.9e-07 | T/18/2.8e-10 | T/17/7.4e-10 | T/18/2.8e-10 |
| D free first, W=1.0e6 | 64 | PGD | zero | T/20/1.3e-06 | T/31/7.1e-10 | T/29/2.4e-09 | T/31/7.1e-10 |
| D free first, W=1.0e6 | 64 | APG | zero | T/14/1.9e-07 | T/18/2.8e-10 | T/17/7.4e-10 | T/18/2.8e-10 |
| D free first, W=1.0e12 | 64 | PGD | zero | T/20/1.3e-06 | T/31/7.1e-10 | T/29/2.4e-09 | T/31/7.1e-10 |
| D free first, W=1.0e12 | 64 | APG | zero | T/14/1.9e-07 | T/18/2.8e-10 | T/17/7.4e-10 | T/18/2.8e-10 |
| D free first, W=1.0e100 | 64 | PGD | zero | T/20/1.3e-06 | T/31/7.1e-10 | T/29/2.4e-09 | T/31/7.1e-10 |
| D free first, W=1.0e100 | 64 | APG | zero | T/14/1.9e-07 | T/18/2.8e-10 | T/17/7.4e-10 | T/18/2.8e-10 |
| E tiny+huge weights | 64 | PGD | zero | T/20/1.3e-06 | T/32/1.2e-09 | T/20/1.3e-06 | T/32/1.2e-09 |
| E tiny+huge weights | 64 | APG | zero | T/14/1.9e-07 | T/18/2.8e-10 | T/14/1.9e-07 | T/18/2.8e-10 |
| F ordinary weights λ=0.01λmax | 64 | PGD | zero | T/47/3.3e-09 | T/47/3.3e-09 | T/47/3.3e-09 | T/47/3.3e-09 |
| F ordinary weights λ=0.01λmax | 64 | APG | zero | T/32/2.1e-09 | T/32/2.1e-09 | T/32/2.1e-09 | T/32/2.1e-09 |
| F ordinary weights λ=0.1λmax | 64 | PGD | zero | T/28/3.7e-10 | T/28/3.7e-10 | T/28/3.7e-10 | T/28/3.7e-10 |
| F ordinary weights λ=0.1λmax | 64 | APG | zero | T/17/3.0e-10 | T/17/3.0e-10 | T/17/3.0e-10 | T/17/3.0e-10 |
| F ordinary weights λ=0.5λmax | 64 | PGD | zero | T/7/1.0e-11 | T/7/1.0e-11 | T/7/1.0e-11 | T/7/1.0e-11 |
| F ordinary weights λ=0.5λmax | 64 | APG | zero | T/8/3.3e-12 | T/8/3.3e-12 | T/8/3.3e-12 | T/8/3.3e-12 |
| F ordinary weights λ=2.0λmax | 64 | PGD | zero | T/1/0.0e+00 | T/1/0.0e+00 | T/1/0.0e+00 | T/1/0.0e+00 |
| F ordinary weights λ=2.0λmax | 64 | APG | zero | T/1/0.0e+00 | T/1/0.0e+00 | T/1/0.0e+00 | T/1/0.0e+00 |
| F all-zero weights | 64 | PGD | zero | T/49/1.7e-08 | T/49/1.7e-08 | T/49/1.7e-08 | T/49/1.7e-08 |
| F all-zero weights | 64 | APG | zero | T/31/1.6e-08 | T/31/1.6e-08 | T/31/1.6e-08 | T/31/1.6e-08 |
| F λ0 = 0 | 64 | PGD | zero | T/49/1.7e-08 | T/49/1.7e-08 | T/49/1.7e-08 | T/49/1.7e-08 |
| F λ0 = 0 | 64 | APG | zero | T/31/1.6e-08 | T/31/1.6e-08 | T/31/1.6e-08 | T/31/1.6e-08 |
| G corr ρ=.95 ordinary | 64 | PGD | zero | F/200/5.9e-06 | F/200/5.9e-06 | F/200/5.9e-06 | F/200/5.9e-06 |
| G corr ρ=.95 ordinary | 64 | APG | zero | T/79/1.2e-08 | T/79/1.2e-08 | T/79/1.2e-08 | T/79/1.2e-08 |
| G corr ρ=.95 huge W | 64 | PGD | zero | T/51/8.6e-07 | T/61/5.5e-09 | T/55/5.0e-08 | T/61/5.5e-09 |
| G corr ρ=.95 huge W | 64 | APG | zero | T/27/4.3e-07 | T/33/9.8e-10 | T/33/9.8e-10 | T/33/9.8e-10 |
| G duplicate column, huge W on copy | 64 | PGD | zero | T/20/1.3e-06 | T/31/7.1e-10 | T/29/2.4e-09 | T/31/7.1e-10 |
| G duplicate column, huge W on copy | 64 | APG | zero | T/14/1.9e-07 | T/18/2.8e-10 | T/17/7.4e-10 | T/18/2.8e-10 |
| H starts ordinary | 64 | PGD | random | T/30/4.2e-10 | T/30/4.2e-10 | T/30/4.2e-10 | T/30/4.2e-10 |
| H starts ordinary | 64 | PGD | reference | T/1/2.0e-33 | T/1/2.0e-33 | T/1/2.0e-33 | T/1/2.0e-33 |
| H starts ordinary | 64 | APG | random | T/18/3.3e-10 | T/18/3.3e-10 | T/18/3.3e-10 | T/18/3.3e-10 |
| H starts ordinary | 64 | APG | reference | T/1/6.8e-33 | T/1/6.8e-33 | T/1/6.8e-33 | T/1/6.8e-33 |
| H starts huge W | 64 | PGD | random | T/23/1.2e-06 | T/32/3.0e-10 | T/30/4.6e-09 | T/32/3.0e-10 |
| H starts huge W | 64 | PGD | reference | T/1/1.7e-28 | T/1/1.7e-28 | T/1/1.7e-28 | T/1/1.7e-28 |
| H starts huge W | 64 | APG | random | T/13/8.1e-07 | T/18/3.3e-10 | T/18/3.3e-10 | T/18/3.3e-10 |
| H starts huge W | 64 | APG | reference | T/1/2.3e-32 | T/1/2.3e-32 | T/1/2.3e-32 | T/1/2.3e-32 |
| I rescale α=1.0e-100 huge W | 64 | PGD | zero | T/28/6.2e-08 | T/33/8.6e-10 | T/29/5.1e-09 | T/33/8.6e-10 |
| I rescale α=1.0e-100 huge W | 64 | APG | zero | T/19/3.3e-06 | T/23/3.1e-10 | T/23/3.1e-10 | T/23/3.1e-10 |
| I rescale α=1.0e-100 ordinary | 64 | PGD | zero | T/37/2.2e-10 | T/37/2.2e-10 | T/37/2.2e-10 | T/37/2.2e-10 |
| I rescale α=1.0e-100 ordinary | 64 | APG | zero | T/24/8.7e-11 | T/24/8.7e-11 | T/24/8.7e-11 | T/24/8.7e-11 |
| I rescale α=1.0e-20 huge W | 64 | PGD | zero | T/28/6.2e-08 | T/32/6.9e-10 | T/29/5.1e-09 | T/32/6.9e-10 |
| I rescale α=1.0e-20 huge W | 64 | APG | zero | T/19/3.3e-06 | T/23/3.1e-10 | T/23/3.1e-10 | T/23/3.1e-10 |
| I rescale α=1.0e-20 ordinary | 64 | PGD | zero | T/39/1.9e-10 | T/39/1.9e-10 | T/39/1.9e-10 | T/39/1.9e-10 |
| I rescale α=1.0e-20 ordinary | 64 | APG | zero | T/24/8.7e-11 | T/24/8.7e-11 | T/24/8.7e-11 | T/24/8.7e-11 |
| I rescale α=1.0e20 huge W | 64 | PGD | zero | T/20/1.3e-06 | T/31/7.1e-10 | T/29/2.4e-09 | T/31/7.1e-10 |
| I rescale α=1.0e20 huge W | 64 | APG | zero | T/14/9.7e-07 | T/21/1.3e-09 | T/21/1.3e-09 | T/21/1.3e-09 |
| I rescale α=1.0e20 ordinary | 64 | PGD | zero | T/28/3.7e-10 | T/28/3.7e-10 | T/28/3.7e-10 | T/28/3.7e-10 |
| I rescale α=1.0e20 ordinary | 64 | APG | zero | T/18/1.1e-10 | T/18/1.1e-10 | T/18/1.1e-10 | T/18/1.1e-10 |
| I rescale α=1.0e100 huge W | 64 | PGD | zero | T/20/1.3e-06 | T/31/7.1e-10 | T/29/2.4e-09 | T/31/7.1e-10 |
| I rescale α=1.0e100 huge W | 64 | APG | zero | T/14/4.1e-07 | T/19/5.3e-10 | T/18/3.7e-09 | T/19/5.3e-10 |
| I rescale α=1.0e100 ordinary | 64 | PGD | zero | T/30/2.5e-10 | T/30/2.5e-10 | T/30/2.5e-10 | T/30/2.5e-10 |
| I rescale α=1.0e100 ordinary | 64 | APG | zero | T/19/4.0e-10 | T/19/4.0e-10 | T/19/4.0e-10 | T/19/4.0e-10 |
| J y=0 mixed weights | 64 | PGD | zero | T/1/0.0e+00 | F/200/0.0e+00 | F/200/0.0e+00 | F/200/0.0e+00 |
| J y=0 mixed weights | 64 | PGD | random | T/10/4.3e-13 | F/200/4.5e-265 | F/200/4.5e-265 | F/200/4.5e-265 |
| J y=0 mixed weights | 64 | APG | zero | T/1/0.0e+00 | F/200/0.0e+00 | F/200/0.0e+00 | F/200/0.0e+00 |
| J y=0 mixed weights | 64 | APG | random | T/9/1.3e-12 | F/200/7.4e-322 | F/200/7.4e-322 | F/200/7.4e-322 |
| J free coord with ∇f_1(0)≈0, huge W | 64 | PGD | zero | T/18/7.7e-07 | T/30/4.1e-10 | T/29/7.4e-10 | T/30/4.1e-10 |
| J free coord with ∇f_1(0)≈0, huge W | 64 | APG | zero | T/14/2.6e-07 | T/20/2.1e-10 | T/18/3.1e-09 | T/20/2.1e-10 |
| K strict, huge W | 64 | PGD | zero | T/81/2.9e-22 | T/81/2.9e-22 | T/81/2.9e-22 | T/81/2.9e-22 |
| K strict, huge W | 64 | APG | zero | T/40/3.1e-22 | T/40/3.1e-22 | T/40/3.1e-22 | T/40/3.1e-22 |
| K maxiter 5000, huge W | 64 | PGD | zero | T/20/1.3e-06 | T/31/7.1e-10 | T/29/2.4e-09 | T/31/7.1e-10 |
| K maxiter 5000, huge W | 64 | APG | zero | T/14/1.9e-07 | T/18/2.8e-10 | T/17/7.4e-10 | T/18/2.8e-10 |
| B zero column W=1.0 | 32 | PGD | zero | F+/28/4.9e-09 | F+/28/4.9e-09 | F+/28/4.9e-09 | F+/28/4.9e-09 |
| B zero column W=1.0 | 32 | APG | zero | F+/18/1.9e-09 | F+/18/1.9e-09 | F+/18/1.9e-09 | F+/18/1.9e-09 |
| B zero column W=1000.0 | 32 | PGD | zero | T/19/1.0e-06 | F+/28/4.9e-09 | T/19/1.0e-06 | F+/28/4.9e-09 |
| B zero column W=1000.0 | 32 | APG | zero | T/14/1.1e-06 | F+/18/1.9e-09 | T/14/1.1e-06 | F+/18/1.9e-09 |
| B zero column W=1.0e6 | 32 | PGD | zero | T/19/1.0e-06 | F+/28/4.9e-09 | T/19/1.0e-06 | F+/28/4.9e-09 |
| B zero column W=1.0e6 | 32 | APG | zero | T/14/1.1e-06 | F+/18/1.9e-09 | T/14/1.1e-06 | F+/18/1.9e-09 |
| B zero column W=1.0e12 | 32 | PGD | zero | T/19/1.0e-06 | F+/28/4.9e-09 | T/19/1.0e-06 | F+/28/4.9e-09 |
| B zero column W=1.0e12 | 32 | APG | zero | T/14/1.1e-06 | F+/18/1.9e-09 | T/14/1.1e-06 | F+/18/1.9e-09 |
| B zero column W=1.0e30 | 32 | PGD | zero | T/19/1.0e-06 | F+/28/4.9e-09 | T/19/1.0e-06 | F+/28/4.9e-09 |
| B zero column W=1.0e30 | 32 | APG | zero | T/14/1.1e-06 | F+/18/1.9e-09 | T/14/1.1e-06 | F+/18/1.9e-09 |
| B reduced (no zero column) | 32 | PGD | zero | F+/28/4.9e-09 | F+/28/4.9e-09 | F+/28/4.9e-09 | F+/28/4.9e-09 |
| B reduced (no zero column) | 32 | APG | zero | F+/18/1.9e-09 | F+/18/1.9e-09 | F+/18/1.9e-09 | F+/18/1.9e-09 |
| C excluded column W=1.0 | 32 | PGD | zero | F+/28/4.9e-09 | F+/28/4.9e-09 | F+/28/4.9e-09 | F+/28/4.9e-09 |
| C excluded column W=1.0 | 32 | APG | zero | F+/18/1.9e-09 | F+/18/1.9e-09 | F+/18/1.9e-09 | F+/18/1.9e-09 |
| C excluded column W=1000.0 | 32 | PGD | zero | T/19/8.0e-07 | T/29/5.4e-10 | T/19/8.0e-07 | T/29/5.4e-10 |
| C excluded column W=1000.0 | 32 | APG | zero | T/14/8.6e-08 | T/18/1.3e-10 | T/14/8.6e-08 | T/18/1.3e-10 |
| C excluded column W=1.0e6 | 32 | PGD | zero | T/19/8.0e-07 | T/29/5.4e-10 | T/19/8.0e-07 | T/29/5.4e-10 |
| C excluded column W=1.0e6 | 32 | APG | zero | T/14/8.6e-08 | T/18/1.3e-10 | T/14/8.6e-08 | T/18/1.3e-10 |
| C excluded column W=1.0e12 | 32 | PGD | zero | T/19/8.0e-07 | T/29/5.4e-10 | T/19/8.0e-07 | T/29/5.4e-10 |
| C excluded column W=1.0e12 | 32 | APG | zero | T/14/8.6e-08 | T/18/1.3e-10 | T/14/8.6e-08 | T/18/1.3e-10 |
| C excluded column W=1.0e30 | 32 | PGD | zero | T/19/8.0e-07 | T/29/5.4e-10 | T/19/8.0e-07 | T/29/5.4e-10 |
| C excluded column W=1.0e30 | 32 | APG | zero | T/14/8.6e-08 | T/18/1.3e-10 | T/14/8.6e-08 | T/18/1.3e-10 |
| D free first, W=1.0 | 32 | PGD | zero | F+/27/1.6e-08 | F+/27/1.6e-08 | F+/27/1.6e-08 | F+/27/1.6e-08 |
| D free first, W=1.0 | 32 | APG | zero | T/18/2.0e-10 | T/18/2.0e-10 | T/18/2.0e-10 | T/18/2.0e-10 |
| D free first, W=1000.0 | 32 | PGD | zero | T/20/1.3e-06 | F+/25/6.8e-08 | F+/25/6.8e-08 | F+/25/6.8e-08 |
| D free first, W=1000.0 | 32 | APG | zero | T/14/1.9e-07 | T/18/4.7e-10 | T/17/7.4e-10 | T/18/4.7e-10 |
| D free first, W=1.0e6 | 32 | PGD | zero | T/20/1.3e-06 | F+/25/6.8e-08 | F+/25/6.8e-08 | F+/25/6.8e-08 |
| D free first, W=1.0e6 | 32 | APG | zero | T/14/1.9e-07 | T/18/4.7e-10 | T/17/7.4e-10 | T/18/4.7e-10 |
| D free first, W=1.0e12 | 32 | PGD | zero | T/20/1.3e-06 | F+/25/6.8e-08 | F+/25/6.8e-08 | F+/25/6.8e-08 |
| D free first, W=1.0e12 | 32 | APG | zero | T/14/1.9e-07 | T/18/4.7e-10 | T/17/7.4e-10 | T/18/4.7e-10 |
| D free first, W=1.0e30 | 32 | PGD | zero | T/20/1.3e-06 | F+/25/6.8e-08 | F+/25/6.8e-08 | F+/25/6.8e-08 |
| D free first, W=1.0e30 | 32 | APG | zero | T/14/1.9e-07 | T/18/4.7e-10 | T/17/7.4e-10 | T/18/4.7e-10 |
| E tiny+huge weights | 32 | PGD | zero | T/20/1.3e-06 | T/31/7.1e-10 | T/20/1.3e-06 | T/31/7.1e-10 |
| E tiny+huge weights | 32 | APG | zero | T/14/1.9e-07 | T/18/2.8e-10 | T/14/1.9e-07 | T/18/2.8e-10 |
| F ordinary weights λ=0.01λmax | 32 | PGD | zero | F+/42/2.3e-08 | F+/42/2.3e-08 | F+/42/2.3e-08 | F+/42/2.3e-08 |
| F ordinary weights λ=0.01λmax | 32 | APG | zero | T/36/9.0e-10 | T/36/9.0e-10 | T/36/9.0e-10 | T/36/9.0e-10 |
| F ordinary weights λ=0.1λmax | 32 | PGD | zero | F+/21/5.4e-08 | F+/21/5.4e-08 | F+/21/5.4e-08 | F+/21/5.4e-08 |
| F ordinary weights λ=0.1λmax | 32 | APG | zero | T/18/3.0e-10 | T/18/3.0e-10 | T/18/3.0e-10 | T/18/3.0e-10 |
| F ordinary weights λ=0.5λmax | 32 | PGD | zero | F+/6/5.0e-10 | F+/6/5.0e-10 | F+/6/5.0e-10 | F+/6/5.0e-10 |
| F ordinary weights λ=0.5λmax | 32 | APG | zero | F+/7/8.8e-10 | F+/7/8.8e-10 | F+/7/8.8e-10 | F+/7/8.8e-10 |
| F ordinary weights λ=2.0λmax | 32 | PGD | zero | T/1/0.0e+00 | T/1/0.0e+00 | T/1/0.0e+00 | T/1/0.0e+00 |
| F ordinary weights λ=2.0λmax | 32 | APG | zero | T/1/0.0e+00 | T/1/0.0e+00 | T/1/0.0e+00 | T/1/0.0e+00 |
| F all-zero weights | 32 | PGD | zero | F+/47/1.5e-07 | F+/47/1.5e-07 | F+/47/1.5e-07 | F+/47/1.5e-07 |
| F all-zero weights | 32 | APG | zero | F+/32/4.9e-08 | F+/32/4.9e-08 | F+/32/4.9e-08 | F+/32/4.9e-08 |
| F λ0 = 0 | 32 | PGD | zero | F+/47/1.5e-07 | F+/47/1.5e-07 | F+/47/1.5e-07 | F+/47/1.5e-07 |
| F λ0 = 0 | 32 | APG | zero | F+/32/4.9e-08 | F+/32/4.9e-08 | F+/32/4.9e-08 | F+/32/4.9e-08 |
| G corr ρ=.95 ordinary | 32 | PGD | zero | F/200/6.4e-06 | F/200/6.4e-06 | F/200/6.4e-06 | F/200/6.4e-06 |
| G corr ρ=.95 ordinary | 32 | APG | zero | F+/66/2.1e-07 | F+/66/2.1e-07 | F+/66/2.1e-07 | F+/66/2.1e-07 |
| G corr ρ=.95 huge W | 32 | PGD | zero | T/51/8.6e-07 | F+/56/3.4e-08 | T/55/5.0e-08 | F+/56/3.4e-08 |
| G corr ρ=.95 huge W | 32 | APG | zero | T/27/4.3e-07 | T/33/9.9e-10 | T/33/9.9e-10 | T/33/9.9e-10 |
| G duplicate column, huge W on copy | 32 | PGD | zero | T/20/1.3e-06 | F+/25/6.8e-08 | F+/25/6.8e-08 | F+/25/6.8e-08 |
| G duplicate column, huge W on copy | 32 | APG | zero | T/14/1.9e-07 | T/18/4.7e-10 | T/17/7.4e-10 | T/18/4.7e-10 |
| H starts ordinary | 32 | PGD | random | F+/28/1.6e-09 | F+/28/1.6e-09 | F+/28/1.6e-09 | F+/28/1.6e-09 |
| H starts ordinary | 32 | PGD | reference | T/1/8.5e-16 | T/1/8.5e-16 | T/1/8.5e-16 | T/1/8.5e-16 |
| H starts ordinary | 32 | APG | random | F+/18/2.0e-09 | F+/18/2.0e-09 | F+/18/2.0e-09 | F+/18/2.0e-09 |
| H starts ordinary | 32 | APG | reference | T/1/5.5e-15 | T/1/5.5e-15 | T/1/5.5e-15 | T/1/5.5e-15 |
| H starts huge W | 32 | PGD | random | T/20/9.0e-07 | F+/24/5.6e-08 | T/20/9.0e-07 | F+/24/5.6e-08 |
| H starts huge W | 32 | PGD | reference | T/1/5.2e-11 | T/1/5.2e-11 | T/1/5.2e-11 | T/1/5.2e-11 |
| H starts huge W | 32 | APG | random | T/13/8.1e-07 | T/18/3.4e-10 | T/18/3.4e-10 | T/18/3.4e-10 |
| H starts huge W | 32 | APG | reference | T/1/3.9e-15 | T/1/3.9e-15 | T/1/3.9e-15 | T/1/3.9e-15 |
| I rescale α=1.0e-12 huge W | 32 | PGD | zero | T/28/6.3e-08 | F+/29/2.8e-08 | F+/29/2.8e-08 | F+/29/2.8e-08 |
| I rescale α=1.0e-12 huge W | 32 | APG | zero | T/19/3.3e-06 | T/23/2.9e-10 | T/23/2.9e-10 | T/23/2.9e-10 |
| I rescale α=1.0e-12 ordinary | 32 | PGD | zero | F+/32/6.2e-09 | F+/32/6.2e-09 | F+/32/6.2e-09 | F+/32/6.2e-09 |
| I rescale α=1.0e-12 ordinary | 32 | APG | zero | T/24/8.6e-11 | T/24/8.6e-11 | T/24/8.6e-11 | T/24/8.6e-11 |
| I rescale α=1.0e12 huge W | 32 | PGD | zero | T/20/1.3e-06 | F+/31/6.1e-09 | F+/31/6.1e-09 | F+/31/6.1e-09 |
| I rescale α=1.0e12 huge W | 32 | APG | zero | T/14/5.4e-07 | T/19/5.6e-10 | T/16/5.7e-08 | T/19/5.6e-10 |
| I rescale α=1.0e12 ordinary | 32 | PGD | zero | F+/22/1.5e-07 | F+/22/1.5e-07 | F+/22/1.5e-07 | F+/22/1.5e-07 |
| I rescale α=1.0e12 ordinary | 32 | APG | zero | F+/15/5.4e-09 | F+/15/5.4e-09 | F+/15/5.4e-09 | F+/15/5.4e-09 |
| J y=0 mixed weights | 32 | PGD | zero | T/1/0.0e+00 | F/200/0.0e+00 | F/200/0.0e+00 | F/200/0.0e+00 |
| J y=0 mixed weights | 32 | PGD | random | T/10/4.3e-13 | F+/63/5.5e-45 | F+/63/5.5e-45 | F+/63/5.5e-45 |
| J y=0 mixed weights | 32 | APG | zero | T/1/0.0e+00 | F/200/0.0e+00 | F/200/0.0e+00 | F/200/0.0e+00 |
| J y=0 mixed weights | 32 | APG | random | T/9/1.3e-12 | F/200/1.1e-82 | F/200/1.1e-82 | F/200/1.1e-82 |
| J free coord with ∇f_1(0)≈0, huge W | 32 | PGD | zero | T/19/8.6e-08 | F+/22/8.9e-10 | T/21/1.6e-09 | F+/22/8.9e-10 |
| J free coord with ∇f_1(0)≈0, huge W | 32 | APG | zero | T/14/1.2e-07 | F+/20/1.9e-09 | F+/20/1.9e-09 | F+/20/1.9e-09 |
| K strict, huge W | 32 | PGD | zero | F*/47/2.2e-14 | F*/47/2.2e-14 | F*/47/2.2e-14 | F*/47/2.2e-14 |
| K strict, huge W | 32 | APG | zero | T/49/4.2e-14 | T/49/4.2e-14 | T/49/4.2e-14 | T/49/4.2e-14 |
| K maxiter 5000, huge W | 32 | PGD | zero | T/20/1.3e-06 | F+/25/6.8e-08 | F+/25/6.8e-08 | F+/25/6.8e-08 |
| K maxiter 5000, huge W | 32 | APG | zero | T/14/1.9e-07 | T/18/4.7e-10 | T/17/7.4e-10 | T/18/4.7e-10 |
| N active c₂=M/10 ≫ λmax, M=1000.0 | 32 | PGD | zero | F+/5/4.3e+00 | F+/5/4.3e+00 | F+/5/4.3e+00 | F+/5/4.3e+00 |
| N active c₂=M/10 ≫ λmax, M=1000.0 | 32 | PGD | reference | T/1/0.0e+00 | T/1/0.0e+00 | T/1/0.0e+00 | T/1/0.0e+00 |
| N active c₂=M/10 ≫ λmax, M=1000.0 | 32 | APG | zero | F+/156/4.3e+00 | F+/156/4.3e+00 | F+/156/4.3e+00 | F+/156/4.3e+00 |
| N active c₂=M/10 ≫ λmax, M=1000.0 | 32 | APG | reference | T/1/0.0e+00 | T/1/0.0e+00 | T/1/0.0e+00 | T/1/0.0e+00 |
| N active c₂=M/10 ≫ λmax, M=100000.0 | 32 | PGD | zero | F/200/4.3e+00 | F/200/4.3e+00 | F/200/4.3e+00 | F/200/4.3e+00 |
| N active c₂=M/10 ≫ λmax, M=100000.0 | 32 | PGD | reference | F/200/3.8e-05 | F/200/3.8e-05 | F/200/3.8e-05 | F/200/3.8e-05 |
| N active c₂=M/10 ≫ λmax, M=100000.0 | 32 | APG | zero | F/200/4.3e+00 | F/200/4.3e+00 | F/200/4.3e+00 | F/200/4.3e+00 |
| N active c₂=M/10 ≫ λmax, M=100000.0 | 32 | APG | reference | F/200/3.8e-05 | F/200/3.8e-05 | F/200/3.8e-05 | F/200/3.8e-05 |
| N active c₂=M/10 ≫ λmax, M=1.0e6 | 64 | PGD | zero | F+/10/4.3e+00 | F+/10/4.3e+00 | F+/10/4.3e+00 | F+/10/4.3e+00 |
| N active c₂=M/10 ≫ λmax, M=1.0e6 | 64 | PGD | reference | T/1/0.0e+00 | T/1/0.0e+00 | T/1/0.0e+00 | T/1/0.0e+00 |
| N active c₂=M/10 ≫ λmax, M=1.0e6 | 64 | APG | zero | T/14/4.3e+00 | F/200/4.3e+00 | F/200/4.3e+00 | F/200/4.3e+00 |
| N active c₂=M/10 ≫ λmax, M=1.0e6 | 64 | APG | reference | T/1/0.0e+00 | T/1/0.0e+00 | T/1/0.0e+00 | T/1/0.0e+00 |
| N active c₂=M/10 ≫ λmax, M=1.0e13 | 64 | PGD | zero | T/32/4.3e+00 | F/200/4.3e+00 | F/200/4.3e+00 | F/200/4.3e+00 |
| N active c₂=M/10 ≫ λmax, M=1.0e13 | 64 | PGD | reference | F/200/1.9e-06 | F/200/1.9e-06 | F/200/1.9e-06 | F/200/1.9e-06 |
| N active c₂=M/10 ≫ λmax, M=1.0e13 | 64 | APG | zero | T/11/4.3e+00 | F/200/4.3e+00 | F/200/4.3e+00 | F/200/4.3e+00 |
| N active c₂=M/10 ≫ λmax, M=1.0e13 | 64 | APG | reference | F/200/1.9e-06 | F/200/1.9e-06 | F/200/1.9e-06 | F/200/1.9e-06 |
| O offset response, free intercept (#400) | 64 | PGD | zero | T/24/6.1e+00 | T/24/6.1e+00 | T/24/6.1e+00 | T/24/6.1e+00 |
| O offset response, free intercept (#400) | 64 | APG | zero | T/25/1.4e+01 | T/25/1.4e+01 | T/25/1.4e+01 | T/25/1.4e+01 |
| O centered control | 64 | PGD | zero | T/12/2.0e-09 | T/13/1.6e-11 | T/13/1.6e-11 | T/13/1.6e-11 |
| O centered control | 64 | APG | zero | T/10/1.0e-09 | T/11/1.6e-10 | T/11/1.6e-10 | T/11/1.6e-10 |
| O offset response, free intercept (#400) | 32 | PGD | zero | T/24/6.1e+00 | T/24/6.1e+00 | T/24/6.1e+00 | T/24/6.1e+00 |
| O offset response, free intercept (#400) | 32 | APG | zero | T/25/1.4e+01 | T/25/1.4e+01 | T/25/1.4e+01 | T/25/1.4e+01 |
| O centered control | 32 | PGD | zero | T/12/2.0e-09 | T/13/1.6e-11 | T/13/1.6e-11 | T/13/1.6e-11 |
| O centered control | 32 | APG | zero | T/12/2.2e-09 | F+/13/6.5e-10 | F+/13/6.5e-10 | F+/13/6.5e-10 |
| L logistic intercept free, zero column W=1.0 | 64 | PGD | zero | T/9/1.7e-11 | T/9/1.7e-11 | T/9/1.7e-11 | T/9/1.7e-11 |
| L logistic intercept free, excluded column W=1.0 | 64 | PGD | zero | T/9/1.7e-11 | T/9/1.7e-11 | T/9/1.7e-11 | T/9/1.7e-11 |
| L logistic intercept free, zero column W=1000.0 | 64 | PGD | zero | T/8/3.1e-09 | T/9/1.7e-11 | T/9/1.7e-11 | T/9/1.7e-11 |
| L logistic intercept free, excluded column W=1000.0 | 64 | PGD | zero | T/8/2.1e-09 | T/9/8.5e-12 | T/9/8.5e-12 | T/9/8.5e-12 |
| L logistic intercept free, zero column W=1.0e6 | 64 | PGD | zero | T/8/3.1e-09 | T/9/1.7e-11 | T/9/1.7e-11 | T/9/1.7e-11 |
| L logistic intercept free, excluded column W=1.0e6 | 64 | PGD | zero | T/8/2.1e-09 | T/9/8.5e-12 | T/9/8.5e-12 | T/9/8.5e-12 |
| L logistic intercept free, zero column W=1.0e12 | 64 | PGD | zero | T/8/3.1e-09 | T/9/1.7e-11 | T/9/1.7e-11 | T/9/1.7e-11 |
| L logistic intercept free, excluded column W=1.0e12 | 64 | PGD | zero | T/8/2.1e-09 | T/9/8.5e-12 | T/9/8.5e-12 | T/9/8.5e-12 |
| L logistic intercept free, zero column W=1.0e100 | 64 | PGD | zero | T/8/3.1e-09 | T/9/1.7e-11 | T/9/1.7e-11 | T/9/1.7e-11 |
| L logistic intercept free, excluded column W=1.0e100 | 64 | PGD | zero | T/8/2.1e-09 | T/9/8.5e-12 | T/9/8.5e-12 | T/9/8.5e-12 |
| L logistic ordinary weights | 64 | PGD | zero | T/9/1.4e-12 | T/9/1.4e-12 | T/9/1.4e-12 | T/9/1.4e-12 |
| M group LS one free (B4 analogue) | 64 | PGD | zero | T/1/2.6e-32 | T/1/2.6e-32 |  |  |
| M group LS one free (B4 analogue) | 64 | APG | zero | T/1/9.3e-01 | T/7/5.8e-11 |  |  |
