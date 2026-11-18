function backtrack!(state, ls::BackTracking{T}, f, g) where T

    # Quick exit if no progress made
    _sub!(state.delta_x, state.x, state.x_previous)
    xy_sq = _norm(state.delta_x)^2

    if xy_sq == zero(T) && isfinite(state.f_x)
      # in the gradient mode, update_state! expects ∇f(x), but state.grad_f_x may
      # hold the gradient at a rejected trial point
      if !state.backtrack_simple
          value_and_gradient_at_x!(state, f)
          state.f_calls += 1
          state.grad_calls += 1
      end
      return true
    end

    # A nonfinite LS trial value supplies neither curvature estimate. Shrink
    # the step, past Lexact if need be, since such a point
    # is never accepted. Taking L̂ = Inf would set L = Inf, and the next trial,
    # with step 0, would return x_previous as if converged.
    if !isfinite(state.f_x)
        state.backtrack_steps += 1
        state.L = next_curvature(state.L, ls.β)
        state.verified_rejection = false
        return false
    end

    local_l = Inf
    L_trial = state.L
    gradient_mode = !state.backtrack_simple
    # Compute Lipschitz estimate
    if state.backtrack_simple
        q_x = state.f_x_previous + _dot( state.delta_x, state.grad_f_x_previous ) + 0.5 * state.L * xy_sq
        local_l = state.L + 2. * max( state.f_x - q_x, zero(T) ) / xy_sq
        # as in TFOCS, keep the function value estimate while f(x) and f(x') are far
        # enough apart to compare in floating point, then switch for good to the
        # gradient estimate, which needs ∇f(x)
        state.backtrack_simple = abs( state.f_x_previous - state.f_x ) >= 1e-10 * max( abs( state.f_x ), abs( state.f_x_previous ) )
        if !state.backtrack_simple
            value_and_gradient_at_x!(state, f)
            state.f_calls += 1
            state.grad_calls += 1
        end
    else
        value_and_gradient_at_x!(state, f)
        state.f_calls += 1
        state.grad_calls += 1
        local_l = _dot_diff(T, state.grad_f_x, state.grad_f_x_previous, state.delta_x)
        local_l *= 2. / xy_sq
    end

    # Exit if Lipschitz criterion satisfied, or if we hit Lexact
    state.backtrack_steps += 1;
    (local_l <= state.L || state.L >= ls.Lexact) && return true
    # A rejection with a non-NaN estimate is decided again by the computed curvature c of the
    # step in the mode in which the estimate was formed; in gradient mode, only when ∇f(x) is
    # finite. With L ≥ c the trial is accepted and the mode is unchanged; for Float64 data
    # this includes a c that over- or underflow of a sum of squares makes spuriously zero (see
    # _step_curvature). Otherwise a finite c replaces the estimate; a nonfinite c (Inf or NaN,
    # from overflow in the product, for Float32 data also from a calling thread that flushes
    # subnormals or a subnormal entry of d̂, and for Float64 data from over- or underflow of a
    # sum of squares) leaves TFOCS's estimate. A NaN estimate, or a gradient estimate from a
    # nonfinite ∇f(x), is kept: the update and the error check below run on it as before. A
    # NaN estimate raises the error; an infinite one raises it unless a finite Lexact caps L.
    # verified: this rejection's check ran and replaced L̂ by a finite computed curvature c
    verified = false
    if !isnan(local_l) && (!gradient_mode || all(isfinite, state.grad_f_x))
        accepted, c = check_rejection!(state, gradient_mode)
        accepted && return true
        verified = isfinite(c)
        verified && (local_l = c)
    end
    # recorded for PGD's stagnation test: whether this retry's L̂ is such a curvature
    state.verified_rejection = verified
    state.L = min( ls.Lexact, max( local_l, next_curvature(state.L, ls.β) ) )
    if !isfinite(state.L)
    d = state.delta_x
    println("  FAIL iter-state: L_prev(trial)=", L_trial, " mode=", gradient_mode ? "grad" : "fval",
            "\n   xy_sq=_norm(d)^2=", xy_sq, " (subnormal=", issubnormal(xy_sq), ")  sum(abs2,d)=", sum(abs2, d),
            "\n   maxabs(d)=", maximum(abs, d), " norm(x)=", norm(state.x), " f_x=", state.f_x, " f_prev=", state.f_x_previous,
            "\n   sum(abs2,dz)=", sum(abs2, state.dz), " norm(dz)=", norm(state.dz),
            "\n   local_l(after check)=", local_l, " verified=", verified,
            "\n   robust c = m α (‖Xd‖/‖d‖)^2 = ", (gradient_mode ? 2 : 1) * state.model.α * (norm(state.dz)/norm(d))^2)
end
isfinite(state.L) || error("line search failed: nonfinite curvature estimate")

    return false
end

