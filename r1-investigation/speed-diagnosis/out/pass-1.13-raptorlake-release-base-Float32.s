	.file	"pass"
	.section	.rodata.cst4,"aM",@progbits,4
	.p2align	2, 0x0                          # -- Begin function julia_pass_3131
.LCPI0_0:
	.long	0x80000000                      # float -0
.LCPI0_2:
	.long	0x0c000000                      # float 9.86076131E-32
.LCPI0_3:
	.long	0x3d800000                      # float 0.0625
.LCPI0_5:
	.long	0x00800000                      # float 1.17549435E-38
.LCPI0_6:
	.long	0x7f7fffff                      # float 3.40282347E+38
	.section	.rodata.cst32,"aM",@progbits,32
	.p2align	5, 0x0
.LCPI0_1:
	.long	0x00000000                      # float 0
	.long	0x80000000                      # float -0
	.long	0x80000000                      # float -0
	.long	0x80000000                      # float -0
	.long	0x80000000                      # float -0
	.long	0x80000000                      # float -0
	.long	0x80000000                      # float -0
	.long	0x80000000                      # float -0
	.section	.rodata.cst16,"aM",@progbits,16
	.p2align	4, 0x0
.LCPI0_4:
	.zero	4
	.long	0x80000000                      # float -0
	.long	0x80000000                      # float -0
	.long	0x80000000                      # float -0
	.section	.ltext,"axl",@progbits
	.globl	julia_pass_3131
	.p2align	4
	.type	julia_pass_3131,@function
julia_pass_3131:                        # @julia_pass_3131
; Function Signature: pass(typeof(M_base.ProximalSolvers._column_dot_rsqr), typeof(M_base.ProximalSolvers._sqrt_minimizer), M_base.ProximalSolvers.SqrtLSModel{Float32, M_base.ProximalSolvers.LSModel{Float32, Float32, Array{Float32, 2}, Array{Float32, 1}}}, Array{Float32, 1}, Int64)
# %bb.0:                                # %top
	#DEBUG_VALUE: pass:m <- [$rdi+0]
	#DEBUG_VALUE: pass:xv <- [$rsi+0]
	#DEBUG_VALUE: pass:reps <- $rdx
	push	rbp
	mov	rbp, rsp
	push	r15
	push	r14
	push	r13
	push	r12
	push	rbx
	sub	rsp, 104
	vxorps	xmm0, xmm0, xmm0
	vmovaps	xmmword ptr [rbp - 80], xmm0
	mov	qword ptr [rbp - 64], 0
	#APP
	mov	rax, qword ptr fs:[0]
	#NO_APP
	mov	rcx, qword ptr [rax - 8]
	mov	qword ptr [rbp - 80], 4
	mov	rax, qword ptr [rcx]
	mov	qword ptr [rbp - 72], rax
	lea	rax, [rbp - 80]
	mov	qword ptr [rcx], rax
	xor	eax, eax
	vxorps	xmm15, xmm15, xmm15
	test	rdx, rdx
	cmovg	rax, rdx
	mov	qword ptr [rbp - 96], rax       # 8-byte Spill
	jle	.LBB0_80
# %bb.1:                                # %L17.preheader
	mov	rbx, rsi
	mov	r11, qword ptr [rsi + 16]
	test	r11, r11
	jle	.LBB0_80
# %bb.2:                                # %L17.preheader3
	mov	r14, rdi
	mov	qword ptr [rbp - 88], rcx       # 8-byte Spill
	mov	r12, qword ptr [rdi]
	vxorps	xmm13, xmm13, xmm13
	mov	eax, 1
	movabs	rcx, offset .LCPI0_0
	vbroadcastss	xmm0, dword ptr [rcx]
	vmovaps	xmmword ptr [rbp - 144], xmm0   # 16-byte Spill
	.p2align	4
.LBB0_4:                                # %L17
                                        # =>This Loop Header: Depth=1
                                        #     Child Loop BB0_6 Depth 2
                                        #       Child Loop BB0_15 Depth 3
                                        #       Child Loop BB0_20 Depth 3
                                        #       Child Loop BB0_23 Depth 3
                                        #       Child Loop BB0_31 Depth 3
                                        #       Child Loop BB0_35 Depth 3
                                        #       Child Loop BB0_38 Depth 3
                                        #       Child Loop BB0_54 Depth 3
                                        #       Child Loop BB0_59 Depth 3
                                        #       Child Loop BB0_62 Depth 3
	mov	qword ptr [rbp - 104], rax      # 8-byte Spill
	test	r11, r11
	jle	.LBB0_78
# %bb.5:                                # %L31.preheader
                                        #   in Loop: Header=BB0_4 Depth=1
	mov	r15d, 1
	xor	r13d, r13d
	mov	qword ptr [rbp - 56], r11       # 8-byte Spill
	jmp	.LBB0_6
	.p2align	4
.LBB0_76:                               # %L579
                                        #   in Loop: Header=BB0_6 Depth=2
	mov	qword ptr [rbp - 64], r12
	mov	rdi, r14
	vmovaps	xmm0, xmm3
	mov	rsi, r15
	vmovss	dword ptr [rbp - 44], xmm15     # 4-byte Spill
	movabs	rax, offset j__sqrt_offrange_step_3141
	vzeroupper
	call	rax
	mov	r11, qword ptr [rbp - 56]       # 8-byte Reload
	vxorps	xmm13, xmm13, xmm13
	vmovss	xmm15, dword ptr [rbp - 44]     # 4-byte Reload
                                        # xmm15 = mem[0],zero,zero,zero
	vmovaps	xmm4, xmm0
.LBB0_77:                               # %L581
                                        #   in Loop: Header=BB0_6 Depth=2
	vaddss	xmm15, xmm15, xmm4
	lea	rax, [r15 + 1]
	add	r13, 4
	cmp	r15, r11
	mov	r15, rax
	je	.LBB0_78
.LBB0_6:                                # %L31
                                        #   Parent Loop BB0_4 Depth=1
                                        # =>  This Loop Header: Depth=2
                                        #       Child Loop BB0_15 Depth 3
                                        #       Child Loop BB0_20 Depth 3
                                        #       Child Loop BB0_23 Depth 3
                                        #       Child Loop BB0_31 Depth 3
                                        #       Child Loop BB0_35 Depth 3
                                        #       Child Loop BB0_38 Depth 3
                                        #       Child Loop BB0_54 Depth 3
                                        #       Child Loop BB0_59 Depth 3
                                        #       Child Loop BB0_62 Depth 3
	mov	rdi, qword ptr [r12 + 32]
	lea	rax, [r15 - 1]
	cmp	rax, qword ptr [rdi + 16]
	jae	.LBB0_81
# %bb.7:                                # %L51
                                        #   in Loop: Header=BB0_6 Depth=2
	mov	r8, qword ptr [r12]
	mov	rsi, qword ptr [r12 + 24]
	mov	rcx, qword ptr [rdi]
	vmovss	xmm0, dword ptr [rcx + 4*r15 - 4] # xmm0 = mem[0],zero,zero,zero
	vucomiss	xmm0, xmm0
	mov	rcx, qword ptr [rsi + 16]
	jp	.LBB0_8
# %bb.24:                               # %L178
                                        #   in Loop: Header=BB0_6 Depth=2
	test	rcx, rcx
	jle	.LBB0_25
# %bb.26:                               # %iter.check447
                                        #   in Loop: Header=BB0_6 Depth=2
	mov	rdx, qword ptr [r8]
	mov	r8, qword ptr [r8 + 16]
	mov	rsi, qword ptr [rsi]
	cmp	rcx, 4
	jae	.LBB0_28
# %bb.27:                               #   in Loop: Header=BB0_6 Depth=2
	vxorps	xmm5, xmm5, xmm5
	xor	edi, edi
	vxorps	xmm6, xmm6, xmm6
	jmp	.LBB0_37
	.p2align	4
.LBB0_25:                               #   in Loop: Header=BB0_6 Depth=2
	vxorps	xmm6, xmm6, xmm6
	vxorps	xmm5, xmm5, xmm5
	jmp	.LBB0_39
	.p2align	4
.LBB0_28:                               # %vector.main.loop.iter.check449
                                        #   in Loop: Header=BB0_6 Depth=2
	cmp	rcx, 32
	jae	.LBB0_30
# %bb.29:                               #   in Loop: Header=BB0_6 Depth=2
	vxorps	xmm5, xmm5, xmm5
	xor	edi, edi
	vxorps	xmm6, xmm6, xmm6
	jmp	.LBB0_34
.LBB0_30:                               # %vector.ph450
                                        #   in Loop: Header=BB0_6 Depth=2
	movabs	rdi, 9223372036854775804
	add	rdi, -28
	and	rdi, rcx
	mov	r9, r8
	imul	r9, r13
	add	r9, rdx
	add	r9, 96
	movabs	r10, offset .LCPI0_0
	vbroadcastss	ymm5, dword ptr [r10]
	movabs	r10, offset .LCPI0_1
	vmovaps	ymm6, ymmword ptr [r10]
	xor	r10d, r10d
	vmovaps	ymm7, ymm5
	vmovaps	ymm8, ymm5
	vmovaps	ymm1, ymm6
	vmovaps	ymm2, ymm5
	vmovaps	ymm3, ymm5
	vmovaps	ymm4, ymm5
	.p2align	4
.LBB0_31:                               # %vector.body453
                                        #   Parent Loop BB0_4 Depth=1
                                        #     Parent Loop BB0_6 Depth=2
                                        # =>    This Inner Loop Header: Depth=3
	vmovups	ymm9, ymmword ptr [rsi + 4*r10]
	vmovups	ymm10, ymmword ptr [rsi + 4*r10 + 32]
	vmovups	ymm11, ymmword ptr [rsi + 4*r10 + 64]
	vmovups	ymm12, ymmword ptr [rsi + 4*r10 + 96]
	vfmadd231ps	ymm6, ymm9, ymmword ptr [r9 + 4*r10 - 96] # ymm6 = (ymm9 * mem) + ymm6
	vfmadd231ps	ymm5, ymm10, ymmword ptr [r9 + 4*r10 - 64] # ymm5 = (ymm10 * mem) + ymm5
	vfmadd231ps	ymm7, ymm11, ymmword ptr [r9 + 4*r10 - 32] # ymm7 = (ymm11 * mem) + ymm7
	vfmadd231ps	ymm8, ymm12, ymmword ptr [r9 + 4*r10] # ymm8 = (ymm12 * mem) + ymm8
	vfmadd231ps	ymm1, ymm9, ymm9        # ymm1 = (ymm9 * ymm9) + ymm1
	vfmadd231ps	ymm2, ymm10, ymm10      # ymm2 = (ymm10 * ymm10) + ymm2
	vfmadd231ps	ymm3, ymm11, ymm11      # ymm3 = (ymm11 * ymm11) + ymm3
	vfmadd231ps	ymm4, ymm12, ymm12      # ymm4 = (ymm12 * ymm12) + ymm4
	add	r10, 32
	cmp	rdi, r10
	jne	.LBB0_31
# %bb.32:                               # %middle.block444
                                        #   in Loop: Header=BB0_6 Depth=2
	vaddps	ymm5, ymm5, ymm6
	vaddps	ymm5, ymm7, ymm5
	vaddps	ymm5, ymm8, ymm5
	vextractf128	xmm6, ymm5, 1
	vaddps	xmm5, xmm5, xmm6
	vshufpd	xmm6, xmm5, xmm5, 1             # xmm6 = xmm5[1,0]
	vaddps	xmm5, xmm5, xmm6
	vmovshdup	xmm6, xmm5              # xmm6 = xmm5[1,1,3,3]
	vaddss	xmm5, xmm5, xmm6
	vaddps	ymm1, ymm2, ymm1
	vaddps	ymm1, ymm3, ymm1
	vaddps	ymm1, ymm4, ymm1
	vextractf128	xmm2, ymm1, 1
	vaddps	xmm1, xmm1, xmm2
	vshufpd	xmm2, xmm1, xmm1, 1             # xmm2 = xmm1[1,0]
	vaddps	xmm1, xmm1, xmm2
	vmovshdup	xmm2, xmm1              # xmm2 = xmm1[1,1,3,3]
	vaddss	xmm6, xmm1, xmm2
	cmp	rcx, rdi
	je	.LBB0_39
# %bb.33:                               # %vec.epilog.iter.check485
                                        #   in Loop: Header=BB0_6 Depth=2
	test	cl, 28
	je	.LBB0_37
.LBB0_34:                               # %vec.epilog.ph484
                                        #   in Loop: Header=BB0_6 Depth=2
	mov	r9, rdi
	mov	rdi, rcx
	movabs	r10, 9223372036854775804
	and	rdi, r10
	vmovaps	xmm1, xmmword ptr [rbp - 144]   # 16-byte Reload
	vblendps	xmm2, xmm1, xmm5, 1             # xmm2 = xmm5[0],xmm1[1,2,3]
	vblendps	xmm1, xmm1, xmm6, 1             # xmm1 = xmm6[0],xmm1[1,2,3]
	mov	r10, r8
	imul	r10, r13
	add	r10, rdx
	.p2align	4
.LBB0_35:                               # %vec.epilog.vector.body490
                                        #   Parent Loop BB0_4 Depth=1
                                        #     Parent Loop BB0_6 Depth=2
                                        # =>    This Inner Loop Header: Depth=3
	vmovups	xmm3, xmmword ptr [rsi + 4*r9]
	vfmadd231ps	xmm2, xmm3, xmmword ptr [r10 + 4*r9] # xmm2 = (xmm3 * mem) + xmm2
	vfmadd231ps	xmm1, xmm3, xmm3        # xmm1 = (xmm3 * xmm3) + xmm1
	add	r9, 4
	cmp	rdi, r9
	jne	.LBB0_35
# %bb.36:                               # %vec.epilog.middle.block482
                                        #   in Loop: Header=BB0_6 Depth=2
	vshufpd	xmm3, xmm2, xmm2, 1             # xmm3 = xmm2[1,0]
	vaddps	xmm2, xmm2, xmm3
	vmovshdup	xmm3, xmm2              # xmm3 = xmm2[1,1,3,3]
	vaddss	xmm5, xmm2, xmm3
	vshufpd	xmm2, xmm1, xmm1, 1             # xmm2 = xmm1[1,0]
	vaddps	xmm1, xmm1, xmm2
	vmovshdup	xmm2, xmm1              # xmm2 = xmm1[1,1,3,3]
	vaddss	xmm6, xmm1, xmm2
	cmp	rcx, rdi
	je	.LBB0_39
.LBB0_37:                               # %L190.preheader
                                        #   in Loop: Header=BB0_6 Depth=2
	imul	r8, r13
	add	rdx, r8
	.p2align	4
.LBB0_38:                               # %L190
                                        #   Parent Loop BB0_4 Depth=1
                                        #     Parent Loop BB0_6 Depth=2
                                        # =>    This Inner Loop Header: Depth=3
	vmovss	xmm1, dword ptr [rsi + 4*rdi]   # xmm1 = mem[0],zero,zero,zero
	vfmadd231ss	xmm5, xmm1, dword ptr [rdx + 4*rdi] # xmm5 = (xmm1 * mem) + xmm5
	lea	r8, [rdi + 1]
	vfmadd231ss	xmm6, xmm1, xmm1        # xmm6 = (xmm1 * xmm1) + xmm6
	mov	rdi, r8
	cmp	rcx, r8
	jne	.LBB0_38
.LBB0_39:                               # %L299
                                        #   in Loop: Header=BB0_6 Depth=2
	cmp	rax, qword ptr [rbx + 16]
	jae	.LBB0_82
# %bb.40:                               # %L311
                                        #   in Loop: Header=BB0_6 Depth=2
	mov	rax, qword ptr [rbx]
	vmovss	xmm3, dword ptr [rax + 4*r15 - 4] # xmm3 = mem[0],zero,zero,zero
	vsubss	xmm1, xmm0, xmm0
	vucomiss	xmm1, xmm1
	jp	.LBB0_76
# %bb.41:                               # %L311
                                        #   in Loop: Header=BB0_6 Depth=2
	mov	rcx, qword ptr [r14]
	mov	rdx, qword ptr [rcx + 24]
	mov	rax, qword ptr [rdx + 16]
	vxorps	xmm14, xmm14, xmm14
	vcvtsi2ss	xmm1, xmm14, rax
	movabs	rsi, offset .LCPI0_2
	vmulss	xmm7, xmm1, dword ptr [rsi]
	vucomiss	xmm0, xmm7
	jb	.LBB0_76
# %bb.42:                               # %L311
                                        #   in Loop: Header=BB0_6 Depth=2
	vsubss	xmm1, xmm6, xmm6
	vucomiss	xmm1, xmm1
	jp	.LBB0_76
# %bb.43:                               # %L311
                                        #   in Loop: Header=BB0_6 Depth=2
	vucomiss	xmm6, xmm7
	jb	.LBB0_76
# %bb.44:                               # %L337
                                        #   in Loop: Header=BB0_6 Depth=2
	vucomiss	xmm13, xmm0
	ja	.LBB0_83
# %bb.45:                               # %L343
                                        #   in Loop: Header=BB0_6 Depth=2
	vmovss	xmm2, dword ptr [r14 + 8]       # xmm2 = mem[0],zero,zero,zero
	vsqrtss	xmm1, xmm0, xmm0
	vxorps	xmm4, xmm4, xmm4
	vucomiss	xmm2, xmm1
	jae	.LBB0_77
# %bb.46:                               # %L348
                                        #   in Loop: Header=BB0_6 Depth=2
	vdivss	xmm8, xmm5, xmm0
	vmulss	xmm0, xmm8, xmm5
	vsubss	xmm0, xmm6, xmm0
	movabs	rsi, offset .LCPI0_3
	vmulss	xmm4, xmm6, dword ptr [rsi]
	vucomiss	xmm4, xmm0
	jbe	.LBB0_66
# %bb.47:                               # %L355
                                        #   in Loop: Header=BB0_6 Depth=2
	test	rax, rax
	jle	.LBB0_48
# %bb.49:                               # %iter.check
                                        #   in Loop: Header=BB0_6 Depth=2
	mov	rsi, qword ptr [rcx]
	mov	rcx, qword ptr [rdx]
	mov	rdx, qword ptr [rsi]
	mov	rdi, qword ptr [rsi + 16]
	cmp	rax, 4
	jae	.LBB0_51
# %bb.50:                               #   in Loop: Header=BB0_6 Depth=2
	vxorps	xmm0, xmm0, xmm0
	xor	esi, esi
	jmp	.LBB0_61
.LBB0_48:                               #   in Loop: Header=BB0_6 Depth=2
	vxorps	xmm0, xmm0, xmm0
	jmp	.LBB0_63
.LBB0_51:                               # %vector.main.loop.iter.check
                                        #   in Loop: Header=BB0_6 Depth=2
	cmp	rax, 32
	jae	.LBB0_53
# %bb.52:                               #   in Loop: Header=BB0_6 Depth=2
	vxorps	xmm0, xmm0, xmm0
	xor	esi, esi
	jmp	.LBB0_58
.LBB0_53:                               # %vector.ph
                                        #   in Loop: Header=BB0_6 Depth=2
	movabs	rsi, 9223372036854775804
	add	rsi, -28
	and	rsi, rax
	vbroadcastss	ymm0, xmm8
	mov	r8, rdi
	imul	r8, r13
	add	r8, rdx
	add	r8, 96
	movabs	r9, offset .LCPI0_0
	vbroadcastss	ymm4, dword ptr [r9]
	movabs	r9, offset .LCPI0_1
	vmovaps	ymm5, ymmword ptr [r9]
	xor	r9d, r9d
	vmovaps	ymm6, ymm4
	vmovaps	ymm9, ymm4
	.p2align	4
.LBB0_54:                               # %vector.body
                                        #   Parent Loop BB0_4 Depth=1
                                        #     Parent Loop BB0_6 Depth=2
                                        # =>    This Inner Loop Header: Depth=3
	vmovups	ymm10, ymmword ptr [rcx + 4*r9]
	vmovups	ymm11, ymmword ptr [rcx + 4*r9 + 32]
	vmovups	ymm12, ymmword ptr [rcx + 4*r9 + 64]
	vmovups	ymm13, ymmword ptr [rcx + 4*r9 + 96]
	vmulps	ymm14, ymm0, ymmword ptr [r8 + 4*r9 - 96]
	vsubps	ymm10, ymm10, ymm14
	vmulps	ymm14, ymm0, ymmword ptr [r8 + 4*r9 - 64]
	vsubps	ymm11, ymm11, ymm14
	vmulps	ymm14, ymm0, ymmword ptr [r8 + 4*r9 - 32]
	vsubps	ymm12, ymm12, ymm14
	vmulps	ymm14, ymm0, ymmword ptr [r8 + 4*r9]
	vsubps	ymm13, ymm13, ymm14
	vfmadd231ps	ymm5, ymm10, ymm10      # ymm5 = (ymm10 * ymm10) + ymm5
	vfmadd231ps	ymm4, ymm11, ymm11      # ymm4 = (ymm11 * ymm11) + ymm4
	vfmadd231ps	ymm6, ymm12, ymm12      # ymm6 = (ymm12 * ymm12) + ymm6
	vfmadd231ps	ymm9, ymm13, ymm13      # ymm9 = (ymm13 * ymm13) + ymm9
	add	r9, 32
	cmp	rsi, r9
	jne	.LBB0_54
# %bb.55:                               # %middle.block
                                        #   in Loop: Header=BB0_6 Depth=2
	vaddps	ymm0, ymm4, ymm5
	vaddps	ymm0, ymm6, ymm0
	vaddps	ymm0, ymm9, ymm0
	vextractf128	xmm4, ymm0, 1
	vaddps	xmm0, xmm0, xmm4
	vshufpd	xmm4, xmm0, xmm0, 1             # xmm4 = xmm0[1,0]
	vaddps	xmm0, xmm0, xmm4
	vmovshdup	xmm4, xmm0              # xmm4 = xmm0[1,1,3,3]
	vaddss	xmm0, xmm0, xmm4
	cmp	rax, rsi
	jne	.LBB0_57
# %bb.56:                               #   in Loop: Header=BB0_6 Depth=2
	vxorps	xmm13, xmm13, xmm13
	jmp	.LBB0_63
.LBB0_57:                               # %vec.epilog.iter.check
                                        #   in Loop: Header=BB0_6 Depth=2
	test	al, 28
	vxorps	xmm13, xmm13, xmm13
	je	.LBB0_61
.LBB0_58:                               # %vec.epilog.ph
                                        #   in Loop: Header=BB0_6 Depth=2
	mov	r8, rsi
	mov	rsi, rax
	movabs	r9, 9223372036854775804
	and	rsi, r9
	movabs	r9, offset .LCPI0_4
	vblendps	xmm0, xmm0, xmmword ptr [r9], 14 # xmm0 = xmm0[0],mem[1,2,3]
	vbroadcastss	xmm4, xmm8
	mov	r9, rdi
	imul	r9, r13
	add	r9, rdx
	.p2align	4
.LBB0_59:                               # %vec.epilog.vector.body
                                        #   Parent Loop BB0_4 Depth=1
                                        #     Parent Loop BB0_6 Depth=2
                                        # =>    This Inner Loop Header: Depth=3
	vmovups	xmm5, xmmword ptr [rcx + 4*r8]
	vmulps	xmm6, xmm4, xmmword ptr [r9 + 4*r8]
	vsubps	xmm5, xmm5, xmm6
	vfmadd231ps	xmm0, xmm5, xmm5        # xmm0 = (xmm5 * xmm5) + xmm0
	add	r8, 4
	cmp	rsi, r8
	jne	.LBB0_59
# %bb.60:                               # %vec.epilog.middle.block
                                        #   in Loop: Header=BB0_6 Depth=2
	vshufpd	xmm4, xmm0, xmm0, 1             # xmm4 = xmm0[1,0]
	vaddps	xmm0, xmm0, xmm4
	vmovshdup	xmm4, xmm0              # xmm4 = xmm0[1,1,3,3]
	vaddss	xmm0, xmm0, xmm4
	cmp	rax, rsi
	je	.LBB0_63
.LBB0_61:                               # %L368.preheader
                                        #   in Loop: Header=BB0_6 Depth=2
	imul	rdi, r13
	add	rdx, rdi
	.p2align	4
.LBB0_62:                               # %L368
                                        #   Parent Loop BB0_4 Depth=1
                                        #     Parent Loop BB0_6 Depth=2
                                        # =>    This Inner Loop Header: Depth=3
	vmovss	xmm4, dword ptr [rcx + 4*rsi]   # xmm4 = mem[0],zero,zero,zero
	vmulss	xmm5, xmm8, dword ptr [rdx + 4*rsi]
	lea	rdi, [rsi + 1]
	vsubss	xmm4, xmm4, xmm5
	vfmadd231ss	xmm0, xmm4, xmm4        # xmm0 = (xmm4 * xmm4) + xmm0
	mov	rsi, rdi
	cmp	rax, rdi
	jne	.LBB0_62
.LBB0_63:                               # %L471
                                        #   in Loop: Header=BB0_6 Depth=2
	vucomiss	xmm0, xmm7
	jb	.LBB0_65
# %bb.64:                               # %L471
                                        #   in Loop: Header=BB0_6 Depth=2
	vsubss	xmm4, xmm0, xmm0
	vucomiss	xmm4, xmm4
	jp	.LBB0_65
.LBB0_66:                               # %L483
                                        #   in Loop: Header=BB0_6 Depth=2
	vucomiss	xmm13, xmm0
	ja	.LBB0_84
# %bb.67:                               # %L488
                                        #   in Loop: Header=BB0_6 Depth=2
	vsubss	xmm4, xmm1, xmm2
	vucomiss	xmm13, xmm4
	movabs	rax, offset .LCPI0_5
	ja	.LBB0_85
# %bb.68:                               # %L495
                                        #   in Loop: Header=BB0_6 Depth=2
	vaddss	xmm5, xmm1, xmm2
	vucomiss	xmm13, xmm5
	ja	.LBB0_86
# %bb.69:                               # %L502
                                        #   in Loop: Header=BB0_6 Depth=2
	vaddss	xmm6, xmm8, xmm3
	vsqrtss	xmm0, xmm0, xmm0
	vsqrtss	xmm3, xmm4, xmm4
	vsqrtss	xmm4, xmm5, xmm5
	vmulss	xmm3, xmm3, xmm4
	vmulss	xmm3, xmm1, xmm3
	vucomiss	xmm3, dword ptr [rax]
	jb	.LBB0_75
# %bb.70:                               # %L502
                                        #   in Loop: Header=BB0_6 Depth=2
	vdivss	xmm3, xmm0, xmm3
	vucomiss	xmm3, dword ptr [rax]
	jb	.LBB0_75
# %bb.71:                               # %L502
                                        #   in Loop: Header=BB0_6 Depth=2
	movabs	rcx, offset .LCPI0_6
	vmovss	xmm4, dword ptr [rcx]           # xmm4 = mem[0],zero,zero,zero
	vucomiss	xmm4, xmm3
	jb	.LBB0_75
# %bb.72:                               # %L502
                                        #   in Loop: Header=BB0_6 Depth=2
	vmulss	xmm3, xmm2, xmm3
	vucomiss	xmm3, dword ptr [rax]
	jb	.LBB0_75
# %bb.73:                               # %L502
                                        #   in Loop: Header=BB0_6 Depth=2
	vucomiss	xmm4, xmm3
	jb	.LBB0_75
# %bb.74:                               # %L535
                                        #   in Loop: Header=BB0_6 Depth=2
	movabs	rax, offset .LCPI0_0
	vbroadcastss	xmm0, dword ptr [rax]
	vxorps	xmm0, xmm3, xmm0
	vmaxss	xmm0, xmm6, xmm0
	vminss	xmm0, xmm0, xmm3
	vsubss	xmm0, xmm6, xmm0
	vaddss	xmm4, xmm13, xmm0
	jmp	.LBB0_77
.LBB0_75:                               # %L576
                                        #   in Loop: Header=BB0_6 Depth=2
	vcvtss2sd	xmm3, xmm0, xmm0
	mov	qword ptr [rbp - 64], r12
	vmovaps	xmm0, xmm6
	xor	edi, edi
	vmovss	dword ptr [rbp - 44], xmm15     # 4-byte Spill
	movabs	rax, offset j__sqrt_band_step_3140
	vzeroupper
	call	rax
	mov	r11, qword ptr [rbp - 56]       # 8-byte Reload
	vxorps	xmm13, xmm13, xmm13
	vmovss	xmm15, dword ptr [rbp - 44]     # 4-byte Reload
                                        # xmm15 = mem[0],zero,zero,zero
	vmovaps	xmm4, xmm0
	jmp	.LBB0_77
.LBB0_65:                               # %L481
                                        #   in Loop: Header=BB0_6 Depth=2
	mov	qword ptr [rbp - 64], r12
	mov	rdi, r14
	vmovaps	xmm0, xmm3
	mov	rsi, r15
	vmovss	dword ptr [rbp - 44], xmm15     # 4-byte Spill
	movabs	rax, offset j__sqrt_offrange_step_3141
	vzeroupper
	call	rax
	mov	r11, qword ptr [rbp - 56]       # 8-byte Reload
	vxorps	xmm13, xmm13, xmm13
	vmovss	xmm15, dword ptr [rbp - 44]     # 4-byte Reload
                                        # xmm15 = mem[0],zero,zero,zero
	vmovaps	xmm4, xmm0
	jmp	.LBB0_77
.LBB0_8:                                # %L58
                                        #   in Loop: Header=BB0_6 Depth=2
	test	rcx, rcx
	jle	.LBB0_9
# %bb.10:                               # %iter.check504
                                        #   in Loop: Header=BB0_6 Depth=2
	mov	rdx, qword ptr [r8]
	mov	r8, qword ptr [r8 + 16]
	mov	rsi, qword ptr [rsi]
	cmp	rcx, 4
	jae	.LBB0_12
# %bb.11:                               #   in Loop: Header=BB0_6 Depth=2
	vxorps	xmm0, xmm0, xmm0
	xor	edi, edi
	vxorps	xmm5, xmm5, xmm5
	vxorps	xmm6, xmm6, xmm6
	jmp	.LBB0_22
.LBB0_9:                                #   in Loop: Header=BB0_6 Depth=2
	vxorps	xmm6, xmm6, xmm6
	vxorps	xmm5, xmm5, xmm5
	vxorps	xmm0, xmm0, xmm0
	jmp	.LBB0_39
.LBB0_12:                               # %vector.main.loop.iter.check506
                                        #   in Loop: Header=BB0_6 Depth=2
	vmovaps	xmm10, xmm15
	cmp	rcx, 16
	jae	.LBB0_14
# %bb.13:                               #   in Loop: Header=BB0_6 Depth=2
	vxorps	xmm0, xmm0, xmm0
	xor	edi, edi
	vxorps	xmm5, xmm5, xmm5
	vxorps	xmm6, xmm6, xmm6
	jmp	.LBB0_19
.LBB0_14:                               # %vector.ph507
                                        #   in Loop: Header=BB0_6 Depth=2
	movabs	rdi, 9223372036854775804
	add	rdi, -12
	and	rdi, rcx
	mov	r9, r8
	imul	r9, r13
	add	r9, rdx
	add	r9, 32
	movabs	r10, offset .LCPI0_0
	vbroadcastss	ymm0, dword ptr [r10]
	movabs	r10, offset .LCPI0_1
	vmovaps	ymm5, ymmword ptr [r10]
	xor	r10d, r10d
	vmovaps	ymm3, ymm5
	vmovaps	ymm4, ymm0
	vmovaps	ymm1, ymm5
	vmovaps	ymm2, ymm0
.LBB0_15:                               # %vector.body510
                                        #   Parent Loop BB0_4 Depth=1
                                        #     Parent Loop BB0_6 Depth=2
                                        # =>    This Inner Loop Header: Depth=3
	vmovups	ymm6, ymmword ptr [r9 + 4*r10 - 32]
	vmovups	ymm7, ymmword ptr [r9 + 4*r10]
	vmovups	ymm8, ymmword ptr [rsi + 4*r10]
	vmovups	ymm9, ymmword ptr [rsi + 4*r10 + 32]
	vfmadd231ps	ymm5, ymm6, ymm6        # ymm5 = (ymm6 * ymm6) + ymm5
	vfmadd231ps	ymm0, ymm7, ymm7        # ymm0 = (ymm7 * ymm7) + ymm0
	vfmadd231ps	ymm3, ymm8, ymm6        # ymm3 = (ymm8 * ymm6) + ymm3
	vfmadd231ps	ymm4, ymm9, ymm7        # ymm4 = (ymm9 * ymm7) + ymm4
	vfmadd231ps	ymm1, ymm8, ymm8        # ymm1 = (ymm8 * ymm8) + ymm1
	vfmadd231ps	ymm2, ymm9, ymm9        # ymm2 = (ymm9 * ymm9) + ymm2
	add	r10, 16
	cmp	rdi, r10
	jne	.LBB0_15
# %bb.16:                               # %middle.block501
                                        #   in Loop: Header=BB0_6 Depth=2
	vaddps	ymm0, ymm0, ymm5
	vextractf128	xmm5, ymm0, 1
	vaddps	xmm0, xmm0, xmm5
	vshufpd	xmm5, xmm0, xmm0, 1             # xmm5 = xmm0[1,0]
	vaddps	xmm0, xmm0, xmm5
	vmovshdup	xmm5, xmm0              # xmm5 = xmm0[1,1,3,3]
	vaddss	xmm0, xmm0, xmm5
	vaddps	ymm3, ymm4, ymm3
	vextractf128	xmm4, ymm3, 1
	vaddps	xmm3, xmm3, xmm4
	vshufpd	xmm4, xmm3, xmm3, 1             # xmm4 = xmm3[1,0]
	vaddps	xmm3, xmm3, xmm4
	vmovshdup	xmm4, xmm3              # xmm4 = xmm3[1,1,3,3]
	vaddss	xmm5, xmm3, xmm4
	vaddps	ymm1, ymm2, ymm1
	vextractf128	xmm2, ymm1, 1
	vaddps	xmm1, xmm1, xmm2
	vshufpd	xmm2, xmm1, xmm1, 1             # xmm2 = xmm1[1,0]
	vaddps	xmm1, xmm1, xmm2
	vmovshdup	xmm2, xmm1              # xmm2 = xmm1[1,1,3,3]
	vaddss	xmm6, xmm1, xmm2
	cmp	rcx, rdi
	jne	.LBB0_18
# %bb.17:                               #   in Loop: Header=BB0_6 Depth=2
	vmovaps	xmm15, xmm10
	vxorps	xmm13, xmm13, xmm13
	mov	r11, qword ptr [rbp - 56]       # 8-byte Reload
	jmp	.LBB0_39
.LBB0_18:                               # %vec.epilog.iter.check534
                                        #   in Loop: Header=BB0_6 Depth=2
	test	cl, 12
	vmovaps	xmm15, xmm10
	vxorps	xmm13, xmm13, xmm13
	mov	r11, qword ptr [rbp - 56]       # 8-byte Reload
	je	.LBB0_22
.LBB0_19:                               # %vec.epilog.ph533
                                        #   in Loop: Header=BB0_6 Depth=2
	mov	r9, rdi
	mov	rdi, rcx
	movabs	r10, 9223372036854775804
	and	rdi, r10
	vmovaps	xmm1, xmmword ptr [rbp - 144]   # 16-byte Reload
	vblendps	xmm0, xmm1, xmm0, 1             # xmm0 = xmm0[0],xmm1[1,2,3]
	vblendps	xmm2, xmm1, xmm5, 1             # xmm2 = xmm5[0],xmm1[1,2,3]
	vblendps	xmm1, xmm1, xmm6, 1             # xmm1 = xmm6[0],xmm1[1,2,3]
	mov	r10, r8
	imul	r10, r13
	add	r10, rdx
.LBB0_20:                               # %vec.epilog.vector.body539
                                        #   Parent Loop BB0_4 Depth=1
                                        #     Parent Loop BB0_6 Depth=2
                                        # =>    This Inner Loop Header: Depth=3
	vmovups	xmm3, xmmword ptr [r10 + 4*r9]
	vmovups	xmm4, xmmword ptr [rsi + 4*r9]
	vfmadd231ps	xmm0, xmm3, xmm3        # xmm0 = (xmm3 * xmm3) + xmm0
	vfmadd231ps	xmm2, xmm4, xmm3        # xmm2 = (xmm4 * xmm3) + xmm2
	vfmadd231ps	xmm1, xmm4, xmm4        # xmm1 = (xmm4 * xmm4) + xmm1
	add	r9, 4
	cmp	rdi, r9
	jne	.LBB0_20
# %bb.21:                               # %vec.epilog.middle.block531
                                        #   in Loop: Header=BB0_6 Depth=2
	vshufpd	xmm3, xmm0, xmm0, 1             # xmm3 = xmm0[1,0]
	vaddps	xmm0, xmm0, xmm3
	vmovshdup	xmm3, xmm0              # xmm3 = xmm0[1,1,3,3]
	vaddss	xmm0, xmm0, xmm3
	vshufpd	xmm3, xmm2, xmm2, 1             # xmm3 = xmm2[1,0]
	vaddps	xmm2, xmm2, xmm3
	vmovshdup	xmm3, xmm2              # xmm3 = xmm2[1,1,3,3]
	vaddss	xmm5, xmm2, xmm3
	vshufpd	xmm2, xmm1, xmm1, 1             # xmm2 = xmm1[1,0]
	vaddps	xmm1, xmm1, xmm2
	vmovshdup	xmm2, xmm1              # xmm2 = xmm1[1,1,3,3]
	vaddss	xmm6, xmm1, xmm2
	cmp	rcx, rdi
	vmovaps	xmm15, xmm10
	vxorps	xmm13, xmm13, xmm13
	mov	r11, qword ptr [rbp - 56]       # 8-byte Reload
	je	.LBB0_39
.LBB0_22:                               # %L71.preheader
                                        #   in Loop: Header=BB0_6 Depth=2
	imul	r8, r13
	add	rdx, r8
.LBB0_23:                               # %L71
                                        #   Parent Loop BB0_4 Depth=1
                                        #     Parent Loop BB0_6 Depth=2
                                        # =>    This Inner Loop Header: Depth=3
	vmovss	xmm1, dword ptr [rdx + 4*rdi]   # xmm1 = mem[0],zero,zero,zero
	vmovss	xmm2, dword ptr [rsi + 4*rdi]   # xmm2 = mem[0],zero,zero,zero
	lea	r8, [rdi + 1]
	vfmadd231ss	xmm0, xmm1, xmm1        # xmm0 = (xmm1 * xmm1) + xmm0
	vfmadd231ss	xmm5, xmm2, xmm1        # xmm5 = (xmm2 * xmm1) + xmm5
	vfmadd231ss	xmm6, xmm2, xmm2        # xmm6 = (xmm2 * xmm2) + xmm6
	mov	rdi, r8
	cmp	rcx, r8
	jne	.LBB0_23
	jmp	.LBB0_39
	.p2align	4
.LBB0_78:                               # %L594
                                        #   in Loop: Header=BB0_4 Depth=1
	mov	rax, qword ptr [rbp - 104]      # 8-byte Reload
	cmp	rax, qword ptr [rbp - 96]       # 8-byte Folded Reload
	je	.LBB0_79
# %bb.3:                                # %L17thread-pre-split
                                        #   in Loop: Header=BB0_4 Depth=1
	inc	rax
	mov	r11, qword ptr [rbx + 16]
	jmp	.LBB0_4
.LBB0_79:
	mov	rcx, qword ptr [rbp - 88]       # 8-byte Reload
.LBB0_80:                               # %L605
	mov	rax, qword ptr [rbp - 72]
	mov	qword ptr [rcx], rax
	vmovaps	xmm0, xmm15
	add	rsp, 104
	pop	rbx
	pop	r12
	pop	r13
	pop	r14
	pop	r15
	pop	rbp
	vzeroupper
	ret
.LBB0_82:                               # %L307
	mov	qword ptr [rbp - 120], r15
	movabs	rax, offset j_throw_boundserror_3133
	lea	rsi, [rbp - 120]
	mov	rdi, rbx
	vzeroupper
	call	rax
.LBB0_81:                               # %L47
	mov	qword ptr [rbp - 112], r15
	mov	qword ptr [rbp - 64], rdi
	movabs	rax, offset j_throw_boundserror_3133
	lea	rsi, [rbp - 112]
	vzeroupper
	call	rax
.LBB0_83:                               # %L341
	movabs	rdi, offset ".Ljl_sym#sqrt#3138.jit"
	movabs	rax, offset j_throw_complex_domainerror_3137
	vzeroupper
	call	rax
.LBB0_84:                               # %L486
	movabs	rdi, offset ".Ljl_sym#sqrt#3138.jit"
	movabs	rax, offset j_throw_complex_domainerror_3137
	vzeroupper
	call	rax
.LBB0_85:                               # %L493
	movabs	rdi, offset ".Ljl_sym#sqrt#3138.jit"
	movabs	rax, offset j_throw_complex_domainerror_3137
	vmovaps	xmm0, xmm4
	vzeroupper
	call	rax
.LBB0_86:                               # %L500
	movabs	rdi, offset ".Ljl_sym#sqrt#3138.jit"
	movabs	rax, offset j_throw_complex_domainerror_3137
	vmovaps	xmm0, xmm5
	vzeroupper
	call	rax
.Lfunc_end0:
	.size	julia_pass_3131, .Lfunc_end0-julia_pass_3131
                                        # -- End function
.set ".Ljl_sym#sqrt#3138.jit", 131248270530416
	.size	".Ljl_sym#sqrt#3138.jit", 8
	.section	".note.GNU-stack","",@progbits
