| rule | solves | converged | converged, excess > 1e-3 | converged, above target | v0 stopped on target, rule did not converge | decision = v0 | total iterations |
|---|---|---|---|---|---|---|---|
| v0 | 206 | 178 | 12 | 61 | 0 | 206 | 7719 |
| v1 | 204 | 129 | 4 | 11 | 44 | 96 | 11381 |
| v2 | 204 | 154 | 4 | 48 | 19 | 140 | 10515 |
| v3 | 204 | 129 | 4 | 11 | 44 | 96 | 11381 |
| gv1 | 2 | 2 | 0 | 0 | 0 | 1 | 8 |

| case | T | solver | start | v0: conv/iter/excess | v1: conv/iter/excess | v2: conv/iter/excess | v3: conv/iter/excess |
|---|---|---|---|---|---|---|---|
| A1 logistic B4 | 64 | PGD | zero | T/1/5.8e-03 | T/6/2.4e-11 | T/6/2.4e-11 | T/6/2.4e-11 |
| A2 LS one free | 64 | PGD | zero | T/1/2.6e-32 | T/1/2.6e-32 | T/1/2.6e-32 | T/1/2.6e-32 |
| A2 LS one free | 64 | APG | zero | T/1/9.3e-01 | T/7/5.8e-11 | T/7/5.8e-11 | T/7/5.8e-11 |
| A3 LS two free | 64 | PGD | zero | T/1/2.3e+00 | T/195/6.4e-08 | T/195/6.4e-08 | T/195/6.4e-08 |
| A3 LS two free | 64 | APG | zero | T/1/5.3e-01 | T/45/3.9e-08 | T/45/3.9e-08 | T/45/3.9e-08 |
| B zero column W=1.0 | 64 | PGD | zero | T/77/1.7e-09 | T/77/1.7e-09 | T/77/1.7e-09 | T/77/1.7e-09 |
| B zero column W=1.0 | 64 | APG | zero | T/27/2.0e-09 | T/27/2.0e-09 | T/27/2.0e-09 | T/27/2.0e-09 |
| B zero column W=1000.0 | 64 | PGD | zero | T/41/4.5e-06 | T/77/1.7e-09 | T/41/4.5e-06 | T/77/1.7e-09 |
| B zero column W=1000.0 | 64 | APG | zero | T/19/7.4e-07 | T/27/2.0e-09 | T/19/7.4e-07 | T/27/2.0e-09 |
| B zero column W=1.0e6 | 64 | PGD | zero | T/41/4.5e-06 | T/77/1.7e-09 | T/41/4.5e-06 | T/77/1.7e-09 |
| B zero column W=1.0e6 | 64 | APG | zero | T/19/7.4e-07 | T/27/2.0e-09 | T/19/7.4e-07 | T/27/2.0e-09 |
| B zero column W=1.0e12 | 64 | PGD | zero | T/41/4.5e-06 | T/77/1.7e-09 | T/41/4.5e-06 | T/77/1.7e-09 |
| B zero column W=1.0e12 | 64 | APG | zero | T/19/7.4e-07 | T/27/2.0e-09 | T/19/7.4e-07 | T/27/2.0e-09 |
| B zero column W=1.0e100 | 64 | PGD | zero | T/41/4.5e-06 | T/77/1.7e-09 | T/41/4.5e-06 | T/77/1.7e-09 |
| B zero column W=1.0e100 | 64 | APG | zero | T/19/7.4e-07 | T/27/2.0e-09 | T/19/7.4e-07 | T/27/2.0e-09 |
| B reduced (no zero column) | 64 | PGD | zero | T/77/1.7e-09 | T/77/1.7e-09 | T/77/1.7e-09 | T/77/1.7e-09 |
| B reduced (no zero column) | 64 | APG | zero | T/27/2.0e-09 | T/27/2.0e-09 | T/27/2.0e-09 | T/27/2.0e-09 |
| C excluded column W=1.0 | 64 | PGD | zero | T/77/1.7e-09 | T/77/1.7e-09 | T/77/1.7e-09 | T/77/1.7e-09 |
| C excluded column W=1.0 | 64 | APG | zero | T/27/2.0e-09 | T/27/2.0e-09 | T/27/2.0e-09 | T/27/2.0e-09 |
| C excluded column W=1000.0 | 64 | PGD | zero | T/43/3.8e-06 | T/75/2.2e-09 | T/43/3.8e-06 | T/75/2.2e-09 |
| C excluded column W=1000.0 | 64 | APG | zero | T/20/1.0e-06 | T/30/1.4e-09 | T/20/1.0e-06 | T/30/1.4e-09 |
| C excluded column W=1.0e6 | 64 | PGD | zero | T/43/3.8e-06 | T/75/2.2e-09 | T/43/3.8e-06 | T/75/2.2e-09 |
| C excluded column W=1.0e6 | 64 | APG | zero | T/20/1.0e-06 | T/30/1.4e-09 | T/20/1.0e-06 | T/30/1.4e-09 |
| C excluded column W=1.0e12 | 64 | PGD | zero | T/43/3.8e-06 | T/75/2.2e-09 | T/43/3.8e-06 | T/75/2.2e-09 |
| C excluded column W=1.0e12 | 64 | APG | zero | T/20/1.0e-06 | T/30/1.4e-09 | T/20/1.0e-06 | T/30/1.4e-09 |
| C excluded column W=1.0e100 | 64 | PGD | zero | T/43/3.8e-06 | T/75/2.2e-09 | T/43/3.8e-06 | T/75/2.2e-09 |
| C excluded column W=1.0e100 | 64 | APG | zero | T/20/1.0e-06 | T/30/1.4e-09 | T/20/1.0e-06 | T/30/1.4e-09 |
| D free first, W=1.0 | 64 | PGD | zero | T/75/2.3e-09 | T/75/2.3e-09 | T/75/2.3e-09 | T/75/2.3e-09 |
| D free first, W=1.0 | 64 | APG | zero | T/30/7.8e-10 | T/30/7.8e-10 | T/30/7.8e-10 | T/30/7.8e-10 |
| D free first, W=1000.0 | 64 | PGD | zero | T/46/4.1e-06 | T/75/2.5e-09 | T/66/1.8e-08 | T/75/2.5e-09 |
| D free first, W=1000.0 | 64 | APG | zero | T/19/1.1e-06 | T/30/1.5e-09 | T/28/1.1e-08 | T/30/1.5e-09 |
| D free first, W=1.0e6 | 64 | PGD | zero | T/46/4.1e-06 | T/75/2.5e-09 | T/66/1.8e-08 | T/75/2.5e-09 |
| D free first, W=1.0e6 | 64 | APG | zero | T/19/1.1e-06 | T/30/1.5e-09 | T/28/1.1e-08 | T/30/1.5e-09 |
| D free first, W=1.0e12 | 64 | PGD | zero | T/46/4.1e-06 | T/75/2.5e-09 | T/66/1.8e-08 | T/75/2.5e-09 |
| D free first, W=1.0e12 | 64 | APG | zero | T/19/1.1e-06 | T/30/1.5e-09 | T/28/1.1e-08 | T/30/1.5e-09 |
| D free first, W=1.0e100 | 64 | PGD | zero | T/46/4.1e-06 | T/75/2.5e-09 | T/66/1.8e-08 | T/75/2.5e-09 |
| D free first, W=1.0e100 | 64 | APG | zero | T/19/1.1e-06 | T/30/1.5e-09 | T/28/1.1e-08 | T/30/1.5e-09 |
| E tiny+huge weights | 64 | PGD | zero | T/46/4.1e-06 | T/75/2.5e-09 | T/46/4.1e-06 | T/75/2.5e-09 |
| E tiny+huge weights | 64 | APG | zero | T/19/1.1e-06 | T/30/1.5e-09 | T/19/1.1e-06 | T/30/1.5e-09 |
| F ordinary weights λ=0.01λmax | 64 | PGD | zero | T/104/1.1e-08 | T/104/1.1e-08 | T/104/1.1e-08 | T/104/1.1e-08 |
| F ordinary weights λ=0.01λmax | 64 | APG | zero | T/35/9.6e-09 | T/35/9.6e-09 | T/35/9.6e-09 | T/35/9.6e-09 |
| F ordinary weights λ=0.1λmax | 64 | PGD | zero | T/59/1.6e-09 | T/59/1.6e-09 | T/59/1.6e-09 | T/59/1.6e-09 |
| F ordinary weights λ=0.1λmax | 64 | APG | zero | T/24/3.0e-10 | T/24/3.0e-10 | T/24/3.0e-10 | T/24/3.0e-10 |
| F ordinary weights λ=0.5λmax | 64 | PGD | zero | T/9/2.7e-11 | T/9/2.7e-11 | T/9/2.7e-11 | T/9/2.7e-11 |
| F ordinary weights λ=0.5λmax | 64 | APG | zero | T/12/8.6e-13 | T/12/8.6e-13 | T/12/8.6e-13 | T/12/8.6e-13 |
| F ordinary weights λ=2.0λmax | 64 | PGD | zero | T/1/0.0e+00 | T/1/0.0e+00 | T/1/0.0e+00 | T/1/0.0e+00 |
| F ordinary weights λ=2.0λmax | 64 | APG | zero | T/1/0.0e+00 | T/1/0.0e+00 | T/1/0.0e+00 | T/1/0.0e+00 |
| F all-zero weights | 64 | PGD | zero | T/110/2.6e-08 | T/110/2.6e-08 | T/110/2.6e-08 | T/110/2.6e-08 |
| F all-zero weights | 64 | APG | zero | T/37/1.9e-08 | T/37/1.9e-08 | T/37/1.9e-08 | T/37/1.9e-08 |
| F λ0 = 0 | 64 | PGD | zero | T/110/2.6e-08 | T/110/2.6e-08 | T/110/2.6e-08 | T/110/2.6e-08 |
| F λ0 = 0 | 64 | APG | zero | T/37/1.9e-08 | T/37/1.9e-08 | T/37/1.9e-08 | T/37/1.9e-08 |
| G corr ρ=.95 ordinary | 64 | PGD | zero | T/76/6.5e-09 | T/76/6.5e-09 | T/76/6.5e-09 | T/76/6.5e-09 |
| G corr ρ=.95 ordinary | 64 | APG | zero | T/40/2.7e-09 | T/40/2.7e-09 | T/40/2.7e-09 | T/40/2.7e-09 |
| G corr ρ=.95 huge W | 64 | PGD | zero | T/26/8.9e-08 | T/29/1.7e-10 | T/29/1.7e-10 | T/29/1.7e-10 |
| G corr ρ=.95 huge W | 64 | APG | zero | T/22/1.0e-07 | T/24/7.4e-11 | T/24/7.4e-11 | T/24/7.4e-11 |
| G duplicate column, huge W on copy | 64 | PGD | zero | T/46/4.1e-06 | T/75/2.5e-09 | T/66/1.8e-08 | T/75/2.5e-09 |
| G duplicate column, huge W on copy | 64 | APG | zero | T/19/1.1e-06 | T/30/1.5e-09 | T/28/1.1e-08 | T/30/1.5e-09 |
| H starts ordinary | 64 | PGD | random | T/68/1.9e-09 | T/68/1.9e-09 | T/68/1.9e-09 | T/68/1.9e-09 |
| H starts ordinary | 64 | PGD | reference | T/1/8.3e-29 | T/1/8.3e-29 | T/1/8.3e-29 | T/1/8.3e-29 |
| H starts ordinary | 64 | APG | random | T/26/9.1e-10 | T/26/9.1e-10 | T/26/9.1e-10 | T/26/9.1e-10 |
| H starts ordinary | 64 | APG | reference | T/1/1.9e-33 | T/1/1.9e-33 | T/1/1.9e-33 | T/1/1.9e-33 |
| H starts huge W | 64 | PGD | random | T/48/4.9e-06 | T/77/1.6e-09 | T/60/1.3e-07 | T/77/1.6e-09 |
| H starts huge W | 64 | PGD | reference | T/1/5.6e-29 | T/1/5.6e-29 | T/1/5.6e-29 | T/1/5.6e-29 |
| H starts huge W | 64 | APG | random | T/20/1.8e-06 | T/30/1.3e-09 | T/28/2.2e-08 | T/30/1.3e-09 |
| H starts huge W | 64 | APG | reference | T/1/5.3e-33 | T/1/5.3e-33 | T/1/5.3e-33 | T/1/5.3e-33 |
| I rescale α=1.0e-100 huge W | 64 | PGD | zero | T/53/2.4e-06 | T/79/3.8e-09 | T/70/3.2e-08 | T/79/3.8e-09 |
| I rescale α=1.0e-100 huge W | 64 | APG | zero | T/23/9.4e-07 | T/34/1.6e-10 | T/33/3.9e-09 | T/34/1.6e-10 |
| I rescale α=1.0e-100 ordinary | 64 | PGD | zero | T/70/1.1e-09 | T/70/1.1e-09 | T/70/1.1e-09 | T/70/1.1e-09 |
| I rescale α=1.0e-100 ordinary | 64 | APG | zero | T/34/1.8e-09 | T/34/1.8e-09 | T/34/1.8e-09 | T/34/1.8e-09 |
| I rescale α=1.0e-20 huge W | 64 | PGD | zero | T/53/2.4e-06 | T/74/2.2e-09 | T/73/5.1e-09 | T/74/2.2e-09 |
| I rescale α=1.0e-20 huge W | 64 | APG | zero | T/23/9.4e-07 | T/34/1.6e-10 | T/33/3.9e-09 | T/34/1.6e-10 |
| I rescale α=1.0e-20 ordinary | 64 | PGD | zero | T/70/1.1e-09 | T/70/1.1e-09 | T/70/1.1e-09 | T/70/1.1e-09 |
| I rescale α=1.0e-20 ordinary | 64 | APG | zero | T/34/1.8e-09 | T/34/1.8e-09 | T/34/1.8e-09 | T/34/1.8e-09 |
| I rescale α=1.0e20 huge W | 64 | PGD | zero | T/46/4.1e-06 | T/75/2.5e-09 | T/66/1.8e-08 | T/75/2.5e-09 |
| I rescale α=1.0e20 huge W | 64 | APG | zero | T/22/9.1e-07 | T/35/1.6e-09 | T/34/1.8e-08 | T/35/1.6e-09 |
| I rescale α=1.0e20 ordinary | 64 | PGD | zero | T/69/1.9e-09 | T/69/1.9e-09 | T/69/1.9e-09 | T/69/1.9e-09 |
| I rescale α=1.0e20 ordinary | 64 | APG | zero | T/29/1.3e-09 | T/29/1.3e-09 | T/29/1.3e-09 | T/29/1.3e-09 |
| I rescale α=1.0e100 huge W | 64 | PGD | zero | T/46/4.1e-06 | T/75/2.5e-09 | T/66/1.8e-08 | T/75/2.5e-09 |
| I rescale α=1.0e100 huge W | 64 | APG | zero | T/19/4.4e-07 | T/30/1.2e-10 | T/29/3.3e-09 | T/30/1.2e-10 |
| I rescale α=1.0e100 ordinary | 64 | PGD | zero | T/63/1.5e-09 | T/63/1.5e-09 | T/63/1.5e-09 | T/63/1.5e-09 |
| I rescale α=1.0e100 ordinary | 64 | APG | zero | T/20/3.4e-10 | T/20/3.4e-10 | T/20/3.4e-10 | T/20/3.4e-10 |
| J y=0 mixed weights | 64 | PGD | zero | T/1/0.0e+00 | F/200/0.0e+00 | F/200/0.0e+00 | F/200/0.0e+00 |
| J y=0 mixed weights | 64 | PGD | random | T/9/8.9e-12 | F/200/4.8e-264 | F/200/4.8e-264 | F/200/4.8e-264 |
| J y=0 mixed weights | 64 | APG | zero | T/1/0.0e+00 | F/200/0.0e+00 | F/200/0.0e+00 | F/200/0.0e+00 |
| J y=0 mixed weights | 64 | APG | random | T/10/6.0e-14 | F/200/8.2e-321 | F/200/8.2e-321 | F/200/8.2e-321 |
| J free coord with ∇f_1(0)≈0, huge W | 64 | PGD | zero | T/38/7.8e-07 | T/70/2.9e-10 | T/51/3.0e-08 | T/70/2.9e-10 |
| J free coord with ∇f_1(0)≈0, huge W | 64 | APG | zero | T/19/6.0e-07 | T/34/1.2e-10 | T/31/1.7e-09 | T/34/1.2e-10 |
| K strict, huge W | 64 | PGD | zero | T/188/2.1e-22 | T/188/2.1e-22 | T/188/2.1e-22 | T/188/2.1e-22 |
| K strict, huge W | 64 | APG | zero | T/77/1.3e-21 | T/77/1.3e-21 | T/77/1.3e-21 | T/77/1.3e-21 |
| K maxiter 5000, huge W | 64 | PGD | zero | T/46/4.1e-06 | T/75/2.5e-09 | T/66/1.8e-08 | T/75/2.5e-09 |
| K maxiter 5000, huge W | 64 | APG | zero | T/19/1.1e-06 | T/30/1.5e-09 | T/28/1.1e-08 | T/30/1.5e-09 |
| B zero column W=1.0 | 32 | PGD | zero | F+/68/1.2e-08 | F+/68/1.2e-08 | F+/68/1.2e-08 | F+/68/1.2e-08 |
| B zero column W=1.0 | 32 | APG | zero | F+/33/4.3e-09 | F+/33/4.3e-09 | F+/33/4.3e-09 | F+/33/4.3e-09 |
| B zero column W=1000.0 | 32 | PGD | zero | T/41/4.5e-06 | F+/68/1.2e-08 | T/41/4.5e-06 | F+/68/1.2e-08 |
| B zero column W=1000.0 | 32 | APG | zero | T/19/7.4e-07 | F+/33/4.3e-09 | T/19/7.4e-07 | F+/33/4.3e-09 |
| B zero column W=1.0e6 | 32 | PGD | zero | T/41/4.5e-06 | F+/68/1.2e-08 | T/41/4.5e-06 | F+/68/1.2e-08 |
| B zero column W=1.0e6 | 32 | APG | zero | T/19/7.4e-07 | F+/33/4.3e-09 | T/19/7.4e-07 | F+/33/4.3e-09 |
| B zero column W=1.0e12 | 32 | PGD | zero | T/41/4.5e-06 | F+/68/1.2e-08 | T/41/4.5e-06 | F+/68/1.2e-08 |
| B zero column W=1.0e12 | 32 | APG | zero | T/19/7.4e-07 | F+/33/4.3e-09 | T/19/7.4e-07 | F+/33/4.3e-09 |
| B zero column W=1.0e30 | 32 | PGD | zero | T/41/4.5e-06 | F+/68/1.2e-08 | T/41/4.5e-06 | F+/68/1.2e-08 |
| B zero column W=1.0e30 | 32 | APG | zero | T/19/7.4e-07 | F+/33/4.3e-09 | T/19/7.4e-07 | F+/33/4.3e-09 |
| B reduced (no zero column) | 32 | PGD | zero | F+/68/1.2e-08 | F+/68/1.2e-08 | F+/68/1.2e-08 | F+/68/1.2e-08 |
| B reduced (no zero column) | 32 | APG | zero | F+/33/4.3e-09 | F+/33/4.3e-09 | F+/33/4.3e-09 | F+/33/4.3e-09 |
| C excluded column W=1.0 | 32 | PGD | zero | F+/68/1.2e-08 | F+/68/1.2e-08 | F+/68/1.2e-08 | F+/68/1.2e-08 |
| C excluded column W=1.0 | 32 | APG | zero | F+/33/4.3e-09 | F+/33/4.3e-09 | F+/33/4.3e-09 | F+/33/4.3e-09 |
| C excluded column W=1000.0 | 32 | PGD | zero | T/43/3.8e-06 | F+/63/3.4e-08 | T/43/3.8e-06 | F+/63/3.4e-08 |
| C excluded column W=1000.0 | 32 | APG | zero | T/21/4.8e-07 | F+/30/2.9e-08 | T/21/4.8e-07 | F+/30/2.9e-08 |
| C excluded column W=1.0e6 | 32 | PGD | zero | T/43/3.8e-06 | F+/63/3.4e-08 | T/43/3.8e-06 | F+/63/3.4e-08 |
| C excluded column W=1.0e6 | 32 | APG | zero | T/21/4.8e-07 | F+/30/2.9e-08 | T/21/4.8e-07 | F+/30/2.9e-08 |
| C excluded column W=1.0e12 | 32 | PGD | zero | T/43/3.8e-06 | F+/63/3.4e-08 | T/43/3.8e-06 | F+/63/3.4e-08 |
| C excluded column W=1.0e12 | 32 | APG | zero | T/21/4.8e-07 | F+/30/2.9e-08 | T/21/4.8e-07 | F+/30/2.9e-08 |
| C excluded column W=1.0e30 | 32 | PGD | zero | T/43/3.8e-06 | F+/63/3.4e-08 | T/43/3.8e-06 | F+/63/3.4e-08 |
| C excluded column W=1.0e30 | 32 | APG | zero | T/21/4.8e-07 | F+/30/2.9e-08 | T/21/4.8e-07 | F+/30/2.9e-08 |
| D free first, W=1.0 | 32 | PGD | zero | F+/62/8.5e-08 | F+/62/8.5e-08 | F+/62/8.5e-08 | F+/62/8.5e-08 |
| D free first, W=1.0 | 32 | APG | zero | T/34/4.5e-10 | T/34/4.5e-10 | T/34/4.5e-10 | T/34/4.5e-10 |
| D free first, W=1000.0 | 32 | PGD | zero | T/45/5.1e-06 | F+/62/6.6e-08 | F+/62/6.6e-08 | F+/62/6.6e-08 |
| D free first, W=1000.0 | 32 | APG | zero | T/19/1.1e-06 | F+/30/3.6e-09 | T/28/1.1e-08 | F+/30/3.6e-09 |
| D free first, W=1.0e6 | 32 | PGD | zero | T/45/5.1e-06 | F+/62/6.6e-08 | F+/62/6.6e-08 | F+/62/6.6e-08 |
| D free first, W=1.0e6 | 32 | APG | zero | T/19/1.1e-06 | F+/30/3.6e-09 | T/28/1.1e-08 | F+/30/3.6e-09 |
| D free first, W=1.0e12 | 32 | PGD | zero | T/45/5.1e-06 | F+/62/6.6e-08 | F+/62/6.6e-08 | F+/62/6.6e-08 |
| D free first, W=1.0e12 | 32 | APG | zero | T/19/1.1e-06 | F+/30/3.6e-09 | T/28/1.1e-08 | F+/30/3.6e-09 |
| D free first, W=1.0e30 | 32 | PGD | zero | T/45/5.1e-06 | F+/62/6.6e-08 | F+/62/6.6e-08 | F+/62/6.6e-08 |
| D free first, W=1.0e30 | 32 | APG | zero | T/19/1.1e-06 | F+/30/3.6e-09 | T/28/1.1e-08 | F+/30/3.6e-09 |
| E tiny+huge weights | 32 | PGD | zero | T/47/3.2e-06 | F+/59/1.3e-07 | T/47/3.2e-06 | F+/59/1.3e-07 |
| E tiny+huge weights | 32 | APG | zero | T/19/1.1e-06 | F+/28/3.3e-08 | T/19/1.1e-06 | F+/28/3.3e-08 |
| F ordinary weights λ=0.01λmax | 32 | PGD | zero | F+/84/4.7e-07 | F+/84/4.7e-07 | F+/84/4.7e-07 | F+/84/4.7e-07 |
| F ordinary weights λ=0.01λmax | 32 | APG | zero | T/35/9.6e-09 | T/35/9.6e-09 | T/35/9.6e-09 | T/35/9.6e-09 |
| F ordinary weights λ=0.1λmax | 32 | PGD | zero | F+/48/2.7e-07 | F+/48/2.7e-07 | F+/48/2.7e-07 | F+/48/2.7e-07 |
| F ordinary weights λ=0.1λmax | 32 | APG | zero | T/24/3.0e-10 | T/24/3.0e-10 | T/24/3.0e-10 | T/24/3.0e-10 |
| F ordinary weights λ=0.5λmax | 32 | PGD | zero | T/9/2.7e-11 | T/9/2.7e-11 | T/9/2.7e-11 | T/9/2.7e-11 |
| F ordinary weights λ=0.5λmax | 32 | APG | zero | T/13/1.0e-10 | T/13/1.0e-10 | T/13/1.0e-10 | T/13/1.0e-10 |
| F ordinary weights λ=2.0λmax | 32 | PGD | zero | T/1/0.0e+00 | T/1/0.0e+00 | T/1/0.0e+00 | T/1/0.0e+00 |
| F ordinary weights λ=2.0λmax | 32 | APG | zero | T/1/0.0e+00 | T/1/0.0e+00 | T/1/0.0e+00 | T/1/0.0e+00 |
| F all-zero weights | 32 | PGD | zero | F+/95/4.3e-07 | F+/95/4.3e-07 | F+/95/4.3e-07 | F+/95/4.3e-07 |
| F all-zero weights | 32 | APG | zero | T/37/1.9e-08 | T/37/1.9e-08 | T/37/1.9e-08 | T/37/1.9e-08 |
| F λ0 = 0 | 32 | PGD | zero | F+/95/4.3e-07 | F+/95/4.3e-07 | F+/95/4.3e-07 | F+/95/4.3e-07 |
| F λ0 = 0 | 32 | APG | zero | T/37/1.9e-08 | T/37/1.9e-08 | T/37/1.9e-08 | T/37/1.9e-08 |
| G corr ρ=.95 ordinary | 32 | PGD | zero | F+/65/6.7e-08 | F+/65/6.7e-08 | F+/65/6.7e-08 | F+/65/6.7e-08 |
| G corr ρ=.95 ordinary | 32 | APG | zero | F+/35/1.9e-08 | F+/35/1.9e-08 | F+/35/1.9e-08 | F+/35/1.9e-08 |
| G corr ρ=.95 huge W | 32 | PGD | zero | T/32/2.9e-12 | T/32/2.9e-12 | T/32/2.9e-12 | T/32/2.9e-12 |
| G corr ρ=.95 huge W | 32 | APG | zero | T/22/1.0e-07 | T/24/7.2e-11 | T/24/7.2e-11 | T/24/7.2e-11 |
| G duplicate column, huge W on copy | 32 | PGD | zero | T/45/5.1e-06 | F+/62/6.6e-08 | F+/62/6.6e-08 | F+/62/6.6e-08 |
| G duplicate column, huge W on copy | 32 | APG | zero | T/19/1.1e-06 | F+/30/3.6e-09 | T/28/1.1e-08 | F+/30/3.6e-09 |
| H starts ordinary | 32 | PGD | random | F+/55/8.5e-08 | F+/55/8.5e-08 | F+/55/8.5e-08 | F+/55/8.5e-08 |
| H starts ordinary | 32 | PGD | reference | T/1/5.1e-11 | T/1/5.1e-11 | T/1/5.1e-11 | T/1/5.1e-11 |
| H starts ordinary | 32 | APG | random | T/26/4.0e-10 | T/26/4.0e-10 | T/26/4.0e-10 | T/26/4.0e-10 |
| H starts ordinary | 32 | APG | reference | T/1/2.9e-15 | T/1/2.9e-15 | T/1/2.9e-15 | T/1/2.9e-15 |
| H starts huge W | 32 | PGD | random | T/49/5.3e-06 | F+/61/5.5e-08 | F+/61/5.5e-08 | F+/61/5.5e-08 |
| H starts huge W | 32 | PGD | reference | T/1/6.2e-16 | T/1/6.2e-16 | T/1/6.2e-16 | T/1/6.2e-16 |
| H starts huge W | 32 | APG | random | T/20/1.8e-06 | T/30/1.3e-09 | T/28/2.2e-08 | T/30/1.3e-09 |
| H starts huge W | 32 | APG | reference | T/1/2.3e-15 | T/1/2.3e-15 | T/1/2.3e-15 | T/1/2.3e-15 |
| I rescale α=1.0e-12 huge W | 32 | PGD | zero | T/48/1.1e-06 | F+/56/1.7e-07 | T/52/4.3e-07 | F+/56/1.7e-07 |
| I rescale α=1.0e-12 huge W | 32 | APG | zero | T/23/9.4e-07 | F+/33/3.0e-08 | F+/33/3.0e-08 | F+/33/3.0e-08 |
| I rescale α=1.0e-12 ordinary | 32 | PGD | zero | F+/58/1.8e-07 | F+/58/1.8e-07 | F+/58/1.8e-07 | F+/58/1.8e-07 |
| I rescale α=1.0e-12 ordinary | 32 | APG | zero | F+/28/1.3e-08 | F+/28/1.3e-08 | F+/28/1.3e-08 | F+/28/1.3e-08 |
| I rescale α=1.0e12 huge W | 32 | PGD | zero | T/47/3.2e-06 | F+/58/1.5e-07 | F+/58/1.5e-07 | F+/58/1.5e-07 |
| I rescale α=1.0e12 huge W | 32 | APG | zero | T/21/1.3e-06 | F+/25/5.4e-08 | F+/25/5.4e-08 | F+/25/5.4e-08 |
| I rescale α=1.0e12 ordinary | 32 | PGD | zero | F+/53/8.9e-08 | F+/53/8.9e-08 | F+/53/8.9e-08 | F+/53/8.9e-08 |
| I rescale α=1.0e12 ordinary | 32 | APG | zero | F+/24/5.1e-09 | F+/24/5.1e-09 | F+/24/5.1e-09 | F+/24/5.1e-09 |
| J y=0 mixed weights | 32 | PGD | zero | T/1/0.0e+00 | F/200/0.0e+00 | F/200/0.0e+00 | F/200/0.0e+00 |
| J y=0 mixed weights | 32 | PGD | random | T/9/8.9e-12 | F+/56/1.2e-44 | F+/56/1.2e-44 | F+/56/1.2e-44 |
| J y=0 mixed weights | 32 | APG | zero | T/1/0.0e+00 | F/200/0.0e+00 | F/200/0.0e+00 | F/200/0.0e+00 |
| J y=0 mixed weights | 32 | APG | random | T/10/6.0e-14 | F/200/9.0e-83 | F/200/9.0e-83 | F/200/9.0e-83 |
| J free coord with ∇f_1(0)≈0, huge W | 32 | PGD | zero | T/43/1.9e-06 | T/76/3.5e-10 | T/69/2.1e-09 | T/76/3.5e-10 |
| J free coord with ∇f_1(0)≈0, huge W | 32 | APG | zero | T/19/6.0e-07 | T/35/1.9e-10 | T/34/4.8e-10 | T/35/1.9e-10 |
| K strict, huge W | 32 | PGD | zero | F*/143/2.4e-14 | F*/143/2.4e-14 | F*/143/2.4e-14 | F*/143/2.4e-14 |
| K strict, huge W | 32 | APG | zero | T/145/8.4e-15 | T/145/8.4e-15 | T/145/8.4e-15 | T/145/8.4e-15 |
| K maxiter 5000, huge W | 32 | PGD | zero | T/45/5.1e-06 | F+/62/6.6e-08 | F+/62/6.6e-08 | F+/62/6.6e-08 |
| K maxiter 5000, huge W | 32 | APG | zero | T/19/1.1e-06 | F+/30/3.6e-09 | T/28/1.1e-08 | F+/30/3.6e-09 |
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
| O offset response, free intercept (#400) | 64 | PGD | zero | T/27/3.4e+00 | T/27/3.4e+00 | T/27/3.4e+00 | T/27/3.4e+00 |
| O offset response, free intercept (#400) | 64 | APG | zero | T/19/4.6e+01 | T/19/4.6e+01 | T/19/4.6e+01 | T/19/4.6e+01 |
| O centered control | 64 | PGD | zero | T/11/8.8e-12 | T/11/8.8e-12 | T/11/8.8e-12 | T/11/8.8e-12 |
| O centered control | 64 | APG | zero | T/8/1.1e-09 | T/9/5.1e-11 | T/9/5.1e-11 | T/9/5.1e-11 |
| O offset response, free intercept (#400) | 32 | PGD | zero | T/27/3.4e+00 | T/27/3.4e+00 | T/27/3.4e+00 | T/27/3.4e+00 |
| O offset response, free intercept (#400) | 32 | APG | zero | T/19/4.6e+01 | T/19/4.6e+01 | T/19/4.6e+01 | T/19/4.6e+01 |
| O centered control | 32 | PGD | zero | T/11/8.9e-12 | T/11/8.9e-12 | T/11/8.9e-12 | T/11/8.9e-12 |
| O centered control | 32 | APG | zero | T/9/3.8e-10 | F+/9/3.8e-10 | F+/9/3.8e-10 | F+/9/3.8e-10 |
| L logistic intercept free, zero column W=1.0 | 64 | PGD | zero | T/10/2.7e-11 | T/10/2.7e-11 | T/10/2.7e-11 | T/10/2.7e-11 |
| L logistic intercept free, excluded column W=1.0 | 64 | PGD | zero | T/10/2.7e-11 | T/10/2.7e-11 | T/10/2.7e-11 | T/10/2.7e-11 |
| L logistic intercept free, zero column W=1000.0 | 64 | PGD | zero | T/8/8.8e-09 | T/10/2.7e-11 | T/8/8.8e-09 | T/10/2.7e-11 |
| L logistic intercept free, excluded column W=1000.0 | 64 | PGD | zero | T/8/8.8e-09 | T/10/2.7e-11 | T/8/8.8e-09 | T/10/2.7e-11 |
| L logistic intercept free, zero column W=1.0e6 | 64 | PGD | zero | T/8/8.8e-09 | T/10/2.7e-11 | T/8/8.8e-09 | T/10/2.7e-11 |
| L logistic intercept free, excluded column W=1.0e6 | 64 | PGD | zero | T/8/8.8e-09 | T/10/2.7e-11 | T/8/8.8e-09 | T/10/2.7e-11 |
| L logistic intercept free, zero column W=1.0e12 | 64 | PGD | zero | T/8/8.8e-09 | T/10/2.7e-11 | T/8/8.8e-09 | T/10/2.7e-11 |
| L logistic intercept free, excluded column W=1.0e12 | 64 | PGD | zero | T/8/8.8e-09 | T/10/2.7e-11 | T/8/8.8e-09 | T/10/2.7e-11 |
| L logistic intercept free, zero column W=1.0e100 | 64 | PGD | zero | T/8/8.8e-09 | T/10/2.7e-11 | T/8/8.8e-09 | T/10/2.7e-11 |
| L logistic intercept free, excluded column W=1.0e100 | 64 | PGD | zero | T/8/8.8e-09 | T/10/2.7e-11 | T/8/8.8e-09 | T/10/2.7e-11 |
| L logistic ordinary weights | 64 | PGD | zero | T/10/6.5e-14 | T/10/6.5e-14 | T/10/6.5e-14 | T/10/6.5e-14 |
| M group LS one free (B4 analogue) | 64 | PGD | zero | T/1/2.6e-32 | T/1/2.6e-32 |  |  |
| M group LS one free (B4 analogue) | 64 | APG | zero | T/1/9.3e-01 | T/7/5.8e-11 |  |  |
