	.file	"pass"
	.section	.rodata.cst4,"aM",@progbits,4
	.p2align	2, 0x0                          # -- Begin function julia_pass_3915
.LCPI0_0:
	.long	0x80000000                      # float -0
.LCPI0_2:
	.long	0x0c000000                      # float 9.86076131E-32
.LCPI0_3:
	.long	0x3d800000                      # float 0.0625
.LCPI0_5:
	.long	0x7f7fffff                      # float 3.40282347E+38
.LCPI0_6:
	.long	0x00800000                      # float 1.17549435E-38
.LCPI0_7:
	.long	0x3f800000                      # float 1
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
	.globl	julia_pass_3915
	.p2align	4
	.type	julia_pass_3915,@function
julia_pass_3915:                        # @julia_pass_3915
; Function Signature: pass(typeof(M_x1a.ProximalSolvers._column_dot_rsqr), typeof(M_x1a.ProximalSolvers._sqrt_minimizer), M_x1a.ProximalSolvers.SqrtLSModel{Float32, M_x1a.ProximalSolvers.LSModel{Float32, Float32, Array{Float32, 2}, Array{Float32, 1}}}, Array{Float32, 1}, Int64)
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
	sub	rsp, 232
	vxorps	xmm0, xmm0, xmm0
	vmovups	ymmword ptr [rbp - 128], ymm0
	mov	qword ptr [rbp - 88], 0
	mov	qword ptr [rbp - 96], 0
	#APP
	mov	rax, qword ptr fs:[0]
	#NO_APP
	mov	rcx, qword ptr [rax - 8]
	mov	qword ptr [rbp - 128], 16
	mov	rax, qword ptr [rcx]
	mov	qword ptr [rbp - 120], rax
	lea	rax, [rbp - 128]
	mov	qword ptr [rcx], rax
	xor	eax, eax
	vxorps	xmm15, xmm15, xmm15
	test	rdx, rdx
	cmovg	rax, rdx
	mov	qword ptr [rbp - 144], rax      # 8-byte Spill
	jle	.LBB0_81
# %bb.1:                                # %L17.preheader
	mov	r11, rsi
	mov	rbx, qword ptr [rsi + 16]
	test	rbx, rbx
	jle	.LBB0_81
# %bb.2:                                # %L17.preheader3
	mov	r10, rdi
	mov	qword ptr [rbp - 136], rcx      # 8-byte Spill
	mov	r13, qword ptr [rdi]
	vxorps	xmm13, xmm13, xmm13
	mov	eax, 1
	movabs	rcx, offset .LCPI0_0
	vbroadcastss	xmm0, dword ptr [rcx]
	vmovaps	xmmword ptr [rbp - 192], xmm0   # 16-byte Spill
	mov	qword ptr [rbp - 64], r11       # 8-byte Spill
	mov	qword ptr [rbp - 56], rdi       # 8-byte Spill
	.p2align	4
.LBB0_4:                                # %L17
                                        # =>This Loop Header: Depth=1
                                        #     Child Loop BB0_6 Depth 2
                                        #       Child Loop BB0_15 Depth 3
                                        #       Child Loop BB0_20 Depth 3
                                        #       Child Loop BB0_23 Depth 3
                                        #       Child Loop BB0_31 Depth 3
                                        #       Child Loop BB0_36 Depth 3
                                        #       Child Loop BB0_39 Depth 3
                                        #       Child Loop BB0_56 Depth 3
                                        #       Child Loop BB0_61 Depth 3
                                        #       Child Loop BB0_64 Depth 3
	mov	qword ptr [rbp - 152], rax      # 8-byte Spill
	test	rbx, rbx
	jle	.LBB0_79
# %bb.5:                                # %L31.preheader
                                        #   in Loop: Header=BB0_4 Depth=1
	mov	r15d, 1
	xor	r12d, r12d
	jmp	.LBB0_6
	.p2align	4
.LBB0_77:                               # %L561
                                        #   in Loop: Header=BB0_6 Depth=2
	mov	qword ptr [rbp - 104], rdi
	mov	qword ptr [rbp - 88], r13
	mov	qword ptr [rbp - 96], rcx
	mov	rdi, r10
	lea	rsi, [rbp - 248]
	lea	rdx, [rbp - 104]
	lea	r8, [rbp - 68]
	mov	r9, r15
	vmovss	dword ptr [rbp - 44], xmm15     # 4-byte Spill
	movabs	rax, offset j__sqrt_cold_3925
	vzeroupper
	call	rax
	mov	r10, qword ptr [rbp - 56]       # 8-byte Reload
	vxorps	xmm13, xmm13, xmm13
	vmovss	xmm15, dword ptr [rbp - 44]     # 4-byte Reload
                                        # xmm15 = mem[0],zero,zero,zero
	mov	r11, qword ptr [rbp - 64]       # 8-byte Reload
	vmovaps	xmm3, xmm0
.LBB0_78:                               # %L565
                                        #   in Loop: Header=BB0_6 Depth=2
	vaddss	xmm15, xmm15, xmm3
	lea	rax, [r15 + 1]
	add	r12, 4
	mov	rbx, r14
	cmp	r15, r14
	mov	r15, rax
	je	.LBB0_79
.LBB0_6:                                # %L31
                                        #   Parent Loop BB0_4 Depth=1
                                        # =>  This Loop Header: Depth=2
                                        #       Child Loop BB0_15 Depth 3
                                        #       Child Loop BB0_20 Depth 3
                                        #       Child Loop BB0_23 Depth 3
                                        #       Child Loop BB0_31 Depth 3
                                        #       Child Loop BB0_36 Depth 3
                                        #       Child Loop BB0_39 Depth 3
                                        #       Child Loop BB0_56 Depth 3
                                        #       Child Loop BB0_61 Depth 3
                                        #       Child Loop BB0_64 Depth 3
	mov	rdi, qword ptr [r13 + 32]
	lea	rax, [r15 - 1]
	cmp	rax, qword ptr [rdi + 16]
	jae	.LBB0_82
# %bb.7:                                # %L51
                                        #   in Loop: Header=BB0_6 Depth=2
	mov	r8, qword ptr [r13]
	mov	rsi, qword ptr [r13 + 24]
	mov	rcx, qword ptr [rdi]
	vmovss	xmm1, dword ptr [rcx + 4*r15 - 4] # xmm1 = mem[0],zero,zero,zero
	vucomiss	xmm1, xmm1
	mov	rcx, qword ptr [rsi + 16]
	jp	.LBB0_8
# %bb.24:                               # %L178
                                        #   in Loop: Header=BB0_6 Depth=2
	test	rcx, rcx
	jle	.LBB0_25
# %bb.26:                               # %iter.check599
                                        #   in Loop: Header=BB0_6 Depth=2
	mov	rdx, qword ptr [r8]
	mov	r8, qword ptr [r8 + 16]
	mov	rsi, qword ptr [rsi]
	cmp	rcx, 4
	jae	.LBB0_28
# %bb.27:                               #   in Loop: Header=BB0_6 Depth=2
	vxorps	xmm2, xmm2, xmm2
	xor	edi, edi
	vxorps	xmm4, xmm4, xmm4
	jmp	.LBB0_38
	.p2align	4
.LBB0_25:                               #   in Loop: Header=BB0_6 Depth=2
	vxorps	xmm4, xmm4, xmm4
	vxorps	xmm2, xmm2, xmm2
	jmp	.LBB0_40
	.p2align	4
.LBB0_28:                               # %vector.main.loop.iter.check601
                                        #   in Loop: Header=BB0_6 Depth=2
	cmp	rcx, 32
	jae	.LBB0_30
# %bb.29:                               #   in Loop: Header=BB0_6 Depth=2
	vxorps	xmm2, xmm2, xmm2
	xor	edi, edi
	vxorps	xmm4, xmm4, xmm4
	jmp	.LBB0_35
.LBB0_30:                               # %vector.ph602
                                        #   in Loop: Header=BB0_6 Depth=2
	movabs	rdi, 9223372036854775804
	add	rdi, -28
	and	rdi, rcx
	mov	r9, r8
	imul	r9, r12
	add	r9, rdx
	add	r9, 96
	movabs	r10, offset .LCPI0_0
	vbroadcastss	ymm2, dword ptr [r10]
	movabs	r10, offset .LCPI0_1
	vmovaps	ymm6, ymmword ptr [r10]
	xor	r10d, r10d
	vmovaps	ymm7, ymm2
	vmovaps	ymm8, ymm2
	vmovaps	ymm0, ymm6
	vmovaps	ymm3, ymm2
	vmovaps	ymm4, ymm2
	vmovaps	ymm5, ymm2
	.p2align	4
.LBB0_31:                               # %vector.body605
                                        #   Parent Loop BB0_4 Depth=1
                                        #     Parent Loop BB0_6 Depth=2
                                        # =>    This Inner Loop Header: Depth=3
	vmovups	ymm9, ymmword ptr [rsi + 4*r10]
	vmovups	ymm10, ymmword ptr [rsi + 4*r10 + 32]
	vmovups	ymm11, ymmword ptr [rsi + 4*r10 + 64]
	vmovups	ymm12, ymmword ptr [rsi + 4*r10 + 96]
	vfmadd231ps	ymm6, ymm9, ymmword ptr [r9 + 4*r10 - 96] # ymm6 = (ymm9 * mem) + ymm6
	vfmadd231ps	ymm2, ymm10, ymmword ptr [r9 + 4*r10 - 64] # ymm2 = (ymm10 * mem) + ymm2
	vfmadd231ps	ymm7, ymm11, ymmword ptr [r9 + 4*r10 - 32] # ymm7 = (ymm11 * mem) + ymm7
	vfmadd231ps	ymm8, ymm12, ymmword ptr [r9 + 4*r10] # ymm8 = (ymm12 * mem) + ymm8
	vfmadd231ps	ymm0, ymm9, ymm9        # ymm0 = (ymm9 * ymm9) + ymm0
	vfmadd231ps	ymm3, ymm10, ymm10      # ymm3 = (ymm10 * ymm10) + ymm3
	vfmadd231ps	ymm4, ymm11, ymm11      # ymm4 = (ymm11 * ymm11) + ymm4
	vfmadd231ps	ymm5, ymm12, ymm12      # ymm5 = (ymm12 * ymm12) + ymm5
	add	r10, 32
	cmp	rdi, r10
	jne	.LBB0_31
# %bb.32:                               # %middle.block596
                                        #   in Loop: Header=BB0_6 Depth=2
	vaddps	ymm2, ymm2, ymm6
	vaddps	ymm2, ymm7, ymm2
	vaddps	ymm2, ymm8, ymm2
	vextractf128	xmm6, ymm2, 1
	vaddps	xmm2, xmm2, xmm6
	vshufpd	xmm6, xmm2, xmm2, 1             # xmm6 = xmm2[1,0]
	vaddps	xmm2, xmm2, xmm6
	vmovshdup	xmm6, xmm2              # xmm6 = xmm2[1,1,3,3]
	vaddss	xmm2, xmm2, xmm6
	vaddps	ymm0, ymm3, ymm0
	vaddps	ymm0, ymm4, ymm0
	vaddps	ymm0, ymm5, ymm0
	vextractf128	xmm3, ymm0, 1
	vaddps	xmm0, xmm0, xmm3
	vshufpd	xmm3, xmm0, xmm0, 1             # xmm3 = xmm0[1,0]
	vaddps	xmm0, xmm0, xmm3
	vmovshdup	xmm3, xmm0              # xmm3 = xmm0[1,1,3,3]
	vaddss	xmm4, xmm0, xmm3
	cmp	rcx, rdi
	jne	.LBB0_34
# %bb.33:                               #   in Loop: Header=BB0_6 Depth=2
	mov	r10, qword ptr [rbp - 56]       # 8-byte Reload
	jmp	.LBB0_40
.LBB0_34:                               # %vec.epilog.iter.check637
                                        #   in Loop: Header=BB0_6 Depth=2
	test	cl, 28
	mov	r10, qword ptr [rbp - 56]       # 8-byte Reload
	je	.LBB0_38
.LBB0_35:                               # %vec.epilog.ph636
                                        #   in Loop: Header=BB0_6 Depth=2
	mov	r9, rdi
	mov	rdi, rcx
	movabs	r10, 9223372036854775804
	and	rdi, r10
	vmovaps	xmm0, xmmword ptr [rbp - 192]   # 16-byte Reload
	vblendps	xmm2, xmm0, xmm2, 1             # xmm2 = xmm2[0],xmm0[1,2,3]
	vblendps	xmm0, xmm0, xmm4, 1             # xmm0 = xmm4[0],xmm0[1,2,3]
	mov	r10, r8
	imul	r10, r12
	add	r10, rdx
	.p2align	4
.LBB0_36:                               # %vec.epilog.vector.body642
                                        #   Parent Loop BB0_4 Depth=1
                                        #     Parent Loop BB0_6 Depth=2
                                        # =>    This Inner Loop Header: Depth=3
	vmovups	xmm3, xmmword ptr [rsi + 4*r9]
	vfmadd231ps	xmm2, xmm3, xmmword ptr [r10 + 4*r9] # xmm2 = (xmm3 * mem) + xmm2
	vfmadd231ps	xmm0, xmm3, xmm3        # xmm0 = (xmm3 * xmm3) + xmm0
	add	r9, 4
	cmp	rdi, r9
	jne	.LBB0_36
# %bb.37:                               # %vec.epilog.middle.block634
                                        #   in Loop: Header=BB0_6 Depth=2
	vshufpd	xmm3, xmm2, xmm2, 1             # xmm3 = xmm2[1,0]
	vaddps	xmm2, xmm2, xmm3
	vmovshdup	xmm3, xmm2              # xmm3 = xmm2[1,1,3,3]
	vaddss	xmm2, xmm2, xmm3
	vshufpd	xmm3, xmm0, xmm0, 1             # xmm3 = xmm0[1,0]
	vaddps	xmm0, xmm0, xmm3
	vmovshdup	xmm3, xmm0              # xmm3 = xmm0[1,1,3,3]
	vaddss	xmm4, xmm0, xmm3
	cmp	rcx, rdi
	mov	r10, qword ptr [rbp - 56]       # 8-byte Reload
	je	.LBB0_40
.LBB0_38:                               # %L190.preheader
                                        #   in Loop: Header=BB0_6 Depth=2
	imul	r8, r12
	add	rdx, r8
	.p2align	4
.LBB0_39:                               # %L190
                                        #   Parent Loop BB0_4 Depth=1
                                        #     Parent Loop BB0_6 Depth=2
                                        # =>    This Inner Loop Header: Depth=3
	vmovss	xmm0, dword ptr [rsi + 4*rdi]   # xmm0 = mem[0],zero,zero,zero
	vfmadd231ss	xmm2, xmm0, dword ptr [rdx + 4*rdi] # xmm2 = (xmm0 * mem) + xmm2
	lea	r8, [rdi + 1]
	vfmadd231ss	xmm4, xmm0, xmm0        # xmm4 = (xmm0 * xmm0) + xmm4
	mov	rdi, r8
	cmp	rcx, r8
	jne	.LBB0_39
.LBB0_40:                               # %L299
                                        #   in Loop: Header=BB0_6 Depth=2
	cmp	rax, qword ptr [r11 + 16]
	jae	.LBB0_83
# %bb.41:                               # %L311
                                        #   in Loop: Header=BB0_6 Depth=2
	mov	rcx, qword ptr [r10]
	mov	rdi, qword ptr [rcx]
	mov	rdx, qword ptr [rdi + 16]
	cmp	rax, qword ptr [rdi + 24]
	jae	.LBB0_84
# %bb.42:                               # %L344
                                        #   in Loop: Header=BB0_6 Depth=2
	mov	r14, rbx
	mov	rsi, qword ptr [r11]
	vmovss	xmm0, dword ptr [rsi + 4*r15 - 4] # xmm0 = mem[0],zero,zero,zero
	imul	rax, rdx
	mov	qword ptr [rbp - 240], rdx
	mov	qword ptr [rbp - 232], r15
	mov	qword ptr [rbp - 224], rax
	mov	qword ptr [rbp - 216], 1
	mov	rcx, qword ptr [rcx + 24]
	mov	ebx, dword ptr [r10 + 8]
	mov	dword ptr [rbp - 68], ebx
	vsubss	xmm3, xmm1, xmm1
	vucomiss	xmm3, xmm3
	jp	.LBB0_77
# %bb.43:                               # %L344
                                        #   in Loop: Header=BB0_6 Depth=2
	mov	rax, qword ptr [rcx + 16]
	vxorps	xmm14, xmm14, xmm14
	vcvtsi2ss	xmm3, xmm14, rax
	movabs	rsi, offset .LCPI0_2
	vmulss	xmm3, xmm3, dword ptr [rsi]
	vucomiss	xmm1, xmm3
	jb	.LBB0_77
# %bb.44:                               # %L344
                                        #   in Loop: Header=BB0_6 Depth=2
	vsubss	xmm5, xmm4, xmm4
	vucomiss	xmm5, xmm5
	jp	.LBB0_77
# %bb.45:                               # %L344
                                        #   in Loop: Header=BB0_6 Depth=2
	vucomiss	xmm4, xmm3
	jb	.LBB0_77
# %bb.46:                               # %L378
                                        #   in Loop: Header=BB0_6 Depth=2
	vucomiss	xmm13, xmm1
	ja	.LBB0_85
# %bb.47:                               # %L383
                                        #   in Loop: Header=BB0_6 Depth=2
	vmovd	xmm6, ebx
	vsqrtss	xmm8, xmm1, xmm1
	vxorps	xmm3, xmm3, xmm3
	vucomiss	xmm6, xmm8
	jae	.LBB0_78
# %bb.48:                               # %L387
                                        #   in Loop: Header=BB0_6 Depth=2
	vdivss	xmm7, xmm2, xmm1
	vmulss	xmm2, xmm2, xmm7
	vsubss	xmm3, xmm4, xmm2
	movabs	rsi, offset .LCPI0_3
	vmulss	xmm2, xmm4, dword ptr [rsi]
	vucomiss	xmm2, xmm3
	jbe	.LBB0_65
# %bb.49:                               # %L394
                                        #   in Loop: Header=BB0_6 Depth=2
	test	rax, rax
	jle	.LBB0_50
# %bb.51:                               # %iter.check
                                        #   in Loop: Header=BB0_6 Depth=2
	mov	rsi, qword ptr [rcx]
	mov	r8, qword ptr [rdi]
	cmp	rax, 4
	jae	.LBB0_53
# %bb.52:                               #   in Loop: Header=BB0_6 Depth=2
	vxorps	xmm3, xmm3, xmm3
	xor	r9d, r9d
	jmp	.LBB0_63
.LBB0_50:                               #   in Loop: Header=BB0_6 Depth=2
	vxorps	xmm3, xmm3, xmm3
	jmp	.LBB0_66
.LBB0_53:                               # %vector.main.loop.iter.check
                                        #   in Loop: Header=BB0_6 Depth=2
	cmp	rax, 32
	jae	.LBB0_55
# %bb.54:                               #   in Loop: Header=BB0_6 Depth=2
	vxorps	xmm3, xmm3, xmm3
	xor	r9d, r9d
	jmp	.LBB0_60
.LBB0_55:                               # %vector.ph
                                        #   in Loop: Header=BB0_6 Depth=2
	movabs	r9, 9223372036854775804
	add	r9, -28
	and	r9, rax
	vbroadcastss	ymm2, xmm7
	mov	r10, rdx
	imul	r10, r12
	add	r10, r8
	add	r10, 96
	movabs	r11, offset .LCPI0_0
	vbroadcastss	ymm3, dword ptr [r11]
	movabs	r11, offset .LCPI0_1
	vmovaps	ymm4, ymmword ptr [r11]
	xor	r11d, r11d
	vmovaps	ymm5, ymm3
	vmovaps	ymm9, ymm3
	.p2align	4
.LBB0_56:                               # %vector.body
                                        #   Parent Loop BB0_4 Depth=1
                                        #     Parent Loop BB0_6 Depth=2
                                        # =>    This Inner Loop Header: Depth=3
	vmovups	ymm10, ymmword ptr [rsi + 4*r11]
	vmovups	ymm11, ymmword ptr [rsi + 4*r11 + 32]
	vmovups	ymm12, ymmword ptr [rsi + 4*r11 + 64]
	vmovups	ymm13, ymmword ptr [rsi + 4*r11 + 96]
	vmulps	ymm14, ymm2, ymmword ptr [r10 + 4*r11 - 96]
	vsubps	ymm10, ymm10, ymm14
	vmulps	ymm14, ymm2, ymmword ptr [r10 + 4*r11 - 64]
	vsubps	ymm11, ymm11, ymm14
	vmulps	ymm14, ymm2, ymmword ptr [r10 + 4*r11 - 32]
	vsubps	ymm12, ymm12, ymm14
	vmulps	ymm14, ymm2, ymmword ptr [r10 + 4*r11]
	vsubps	ymm13, ymm13, ymm14
	vfmadd231ps	ymm4, ymm10, ymm10      # ymm4 = (ymm10 * ymm10) + ymm4
	vfmadd231ps	ymm3, ymm11, ymm11      # ymm3 = (ymm11 * ymm11) + ymm3
	vfmadd231ps	ymm5, ymm12, ymm12      # ymm5 = (ymm12 * ymm12) + ymm5
	vfmadd231ps	ymm9, ymm13, ymm13      # ymm9 = (ymm13 * ymm13) + ymm9
	add	r11, 32
	cmp	r9, r11
	jne	.LBB0_56
# %bb.57:                               # %middle.block
                                        #   in Loop: Header=BB0_6 Depth=2
	vaddps	ymm2, ymm3, ymm4
	vaddps	ymm2, ymm5, ymm2
	vaddps	ymm2, ymm9, ymm2
	vextractf128	xmm3, ymm2, 1
	vaddps	xmm2, xmm2, xmm3
	vshufpd	xmm3, xmm2, xmm2, 1             # xmm3 = xmm2[1,0]
	vaddps	xmm2, xmm2, xmm3
	vmovshdup	xmm3, xmm2              # xmm3 = xmm2[1,1,3,3]
	vaddss	xmm3, xmm2, xmm3
	cmp	rax, r9
	mov	r10, qword ptr [rbp - 56]       # 8-byte Reload
	jne	.LBB0_59
# %bb.58:                               #   in Loop: Header=BB0_6 Depth=2
	vxorps	xmm13, xmm13, xmm13
	jmp	.LBB0_65
.LBB0_59:                               # %vec.epilog.iter.check
                                        #   in Loop: Header=BB0_6 Depth=2
	test	al, 28
	vxorps	xmm13, xmm13, xmm13
	je	.LBB0_63
.LBB0_60:                               # %vec.epilog.ph
                                        #   in Loop: Header=BB0_6 Depth=2
	mov	r10, r9
	mov	r9, rax
	movabs	r11, 9223372036854775804
	and	r9, r11
	movabs	r11, offset .LCPI0_4
	vblendps	xmm2, xmm3, xmmword ptr [r11], 14 # xmm2 = xmm3[0],mem[1,2,3]
	vbroadcastss	xmm3, xmm7
	mov	r11, rdx
	imul	r11, r12
	add	r11, r8
	.p2align	4
.LBB0_61:                               # %vec.epilog.vector.body
                                        #   Parent Loop BB0_4 Depth=1
                                        #     Parent Loop BB0_6 Depth=2
                                        # =>    This Inner Loop Header: Depth=3
	vmovups	xmm4, xmmword ptr [rsi + 4*r10]
	vmulps	xmm5, xmm3, xmmword ptr [r11 + 4*r10]
	vsubps	xmm4, xmm4, xmm5
	vfmadd231ps	xmm2, xmm4, xmm4        # xmm2 = (xmm4 * xmm4) + xmm2
	add	r10, 4
	cmp	r9, r10
	jne	.LBB0_61
# %bb.62:                               # %vec.epilog.middle.block
                                        #   in Loop: Header=BB0_6 Depth=2
	vshufpd	xmm3, xmm2, xmm2, 1             # xmm3 = xmm2[1,0]
	vaddps	xmm2, xmm2, xmm3
	vmovshdup	xmm3, xmm2              # xmm3 = xmm2[1,1,3,3]
	vaddss	xmm3, xmm2, xmm3
	cmp	rax, r9
	mov	r10, qword ptr [rbp - 56]       # 8-byte Reload
	je	.LBB0_65
.LBB0_63:                               # %L405.preheader
                                        #   in Loop: Header=BB0_6 Depth=2
	imul	rdx, r12
	add	r8, rdx
	.p2align	4
.LBB0_64:                               # %L405
                                        #   Parent Loop BB0_4 Depth=1
                                        #     Parent Loop BB0_6 Depth=2
                                        # =>    This Inner Loop Header: Depth=3
	vmovss	xmm2, dword ptr [rsi + 4*r9]    # xmm2 = mem[0],zero,zero,zero
	vmulss	xmm4, xmm7, dword ptr [r8 + 4*r9]
	lea	rdx, [r9 + 1]
	vsubss	xmm2, xmm2, xmm4
	vfmadd231ss	xmm3, xmm2, xmm2        # xmm3 = (xmm2 * xmm2) + xmm3
	mov	r9, rdx
	cmp	rax, rdx
	jne	.LBB0_64
.LBB0_65:                               # %L471
                                        #   in Loop: Header=BB0_6 Depth=2
	vucomiss	xmm13, xmm3
	ja	.LBB0_86
.LBB0_66:                               # %L476
                                        #   in Loop: Header=BB0_6 Depth=2
	vsubss	xmm4, xmm8, xmm6
	vucomiss	xmm13, xmm4
	ja	.LBB0_87
# %bb.67:                               # %L482
                                        #   in Loop: Header=BB0_6 Depth=2
	vaddss	xmm5, xmm8, xmm6
	vucomiss	xmm13, xmm5
	ja	.LBB0_88
# %bb.68:                               # %L488
                                        #   in Loop: Header=BB0_6 Depth=2
	vmovss	dword ptr [rbp - 44], xmm15     # 4-byte Spill
	vsqrtss	xmm2, xmm4, xmm4
	vsqrtss	xmm4, xmm5, xmm5
	vmulss	xmm2, xmm2, xmm4
	vmulss	xmm2, xmm8, xmm2
	vucomiss	xmm3, xmm13
	setnp	dl
	sete	al
	movabs	rsi, offset .LCPI0_6
	vmovss	xmm4, dword ptr [rsi]           # xmm4 = mem[0],zero,zero,zero
	vucomiss	xmm2, xmm4
	jb	.LBB0_76
# %bb.69:                               # %L488
                                        #   in Loop: Header=BB0_6 Depth=2
	vsqrtss	xmm3, xmm3, xmm3
	vdivss	xmm9, xmm3, xmm2
	vmulss	xmm2, xmm9, xmm6
	and	al, dl
	movabs	rdx, offset .LCPI0_5
	vmovss	xmm3, dword ptr [rdx]           # xmm3 = mem[0],zero,zero,zero
	vcmpleps	xmm5, xmm9, xmm3
	vcmpleps	xmm8, xmm4, xmm9
	vandps	xmm5, xmm8, xmm5
	vmovd	esi, xmm5
	vcmpleps	xmm3, xmm2, xmm3
	vcmpleps	xmm4, xmm4, xmm2
	vandps	xmm3, xmm4, xmm3
	vmovd	edx, xmm3
	and	esi, edx
	or	sil, al
	test	sil, 1
	je	.LBB0_76
# %bb.70:                               # %L511
                                        #   in Loop: Header=BB0_6 Depth=2
	vaddss	xmm1, xmm7, xmm0
	test	dl, 1
	je	.LBB0_72
# %bb.71:                               # %L521
                                        #   in Loop: Header=BB0_6 Depth=2
	movabs	rax, offset .LCPI0_0
	vbroadcastss	xmm0, dword ptr [rax]
	vxorps	xmm0, xmm2, xmm0
	vmaxss	xmm0, xmm1, xmm0
	vminss	xmm0, xmm0, xmm2
	vsubss	xmm0, xmm1, xmm0
	vaddss	xmm3, xmm13, xmm0
	mov	r11, qword ptr [rbp - 64]       # 8-byte Reload
	vmovss	xmm15, dword ptr [rbp - 44]     # 4-byte Reload
                                        # xmm15 = mem[0],zero,zero,zero
	jmp	.LBB0_78
.LBB0_76:                               # %L559
                                        #   in Loop: Header=BB0_6 Depth=2
	mov	qword ptr [rbp - 112], rdi
	mov	qword ptr [rbp - 88], r13
	mov	qword ptr [rbp - 96], rcx
	mov	rdi, r10
	lea	rsi, [rbp - 248]
	lea	rdx, [rbp - 112]
	lea	r8, [rbp - 68]
	mov	r9, r15
	movabs	rax, offset j__sqrt_cold_3925
	vzeroupper
	call	rax
	mov	r10, qword ptr [rbp - 56]       # 8-byte Reload
	vxorps	xmm13, xmm13, xmm13
	vmovaps	xmm3, xmm0
	mov	r11, qword ptr [rbp - 64]       # 8-byte Reload
	vmovss	xmm15, dword ptr [rbp - 44]     # 4-byte Reload
                                        # xmm15 = mem[0],zero,zero,zero
	jmp	.LBB0_78
.LBB0_72:                               # %L541
                                        #   in Loop: Header=BB0_6 Depth=2
	mov	qword ptr [rbp - 88], r13
	movabs	rax, offset .LCPI0_7
	vmovss	xmm2, dword ptr [rax]           # xmm2 = mem[0],zero,zero,zero
	vmovaps	xmm0, xmm9
	vmovss	dword ptr [rbp - 72], xmm1      # 4-byte Spill
	vmovaps	xmm1, xmm6
	movabs	rax, offset j__exceptional_product_3924
	vmovaps	xmmword ptr [rbp - 272], xmm9   # 16-byte Spill
	vzeroupper
	call	rax
	vxorps	xmm13, xmm13, xmm13
	vmovss	xmm4, dword ptr [rbp - 72]      # 4-byte Reload
                                        # xmm4 = mem[0],zero,zero,zero
	vsubss	xmm1, xmm4, xmm0
	vcmpunordss	xmm2, xmm1, xmm1
	vmaxss	xmm3, xmm1, xmm13
	vblendvps	xmm1, xmm3, xmm1, xmm2
	vaddss	xmm0, xmm4, xmm0
	vminss	xmm0, xmm13, xmm0
	vaddss	xmm3, xmm1, xmm0
	and	ebx, 2147483647
	cmp	ebx, 2139095040
	je	.LBB0_73
# %bb.74:                               # %L541
                                        #   in Loop: Header=BB0_6 Depth=2
	mov	r11, qword ptr [rbp - 64]       # 8-byte Reload
	vmovss	xmm15, dword ptr [rbp - 44]     # 4-byte Reload
                                        # xmm15 = mem[0],zero,zero,zero
	mov	r10, qword ptr [rbp - 56]       # 8-byte Reload
	jmp	.LBB0_78
.LBB0_73:                               #   in Loop: Header=BB0_6 Depth=2
	vcmpnless	xmm0, xmm13, dword ptr [rbp - 272] # 16-byte Folded Reload
	vandps	xmm3, xmm0, xmm3
	mov	r11, qword ptr [rbp - 64]       # 8-byte Reload
	vmovss	xmm15, dword ptr [rbp - 44]     # 4-byte Reload
                                        # xmm15 = mem[0],zero,zero,zero
	mov	r10, qword ptr [rbp - 56]       # 8-byte Reload
	jmp	.LBB0_78
.LBB0_8:                                # %L58
                                        #   in Loop: Header=BB0_6 Depth=2
	test	rcx, rcx
	jle	.LBB0_9
# %bb.10:                               # %iter.check656
                                        #   in Loop: Header=BB0_6 Depth=2
	mov	rdx, qword ptr [r8]
	mov	r8, qword ptr [r8 + 16]
	mov	rsi, qword ptr [rsi]
	cmp	rcx, 4
	jae	.LBB0_12
# %bb.11:                               #   in Loop: Header=BB0_6 Depth=2
	vxorps	xmm1, xmm1, xmm1
	xor	edi, edi
	vxorps	xmm2, xmm2, xmm2
	vxorps	xmm4, xmm4, xmm4
	jmp	.LBB0_22
.LBB0_9:                                #   in Loop: Header=BB0_6 Depth=2
	vxorps	xmm4, xmm4, xmm4
	vxorps	xmm2, xmm2, xmm2
	vxorps	xmm1, xmm1, xmm1
	jmp	.LBB0_40
.LBB0_12:                               # %vector.main.loop.iter.check658
                                        #   in Loop: Header=BB0_6 Depth=2
	mov	r14, rbx
	vmovaps	xmm10, xmm15
	cmp	rcx, 16
	jae	.LBB0_14
# %bb.13:                               #   in Loop: Header=BB0_6 Depth=2
	vxorps	xmm1, xmm1, xmm1
	xor	edi, edi
	vxorps	xmm2, xmm2, xmm2
	vxorps	xmm4, xmm4, xmm4
	jmp	.LBB0_19
.LBB0_14:                               # %vector.ph659
                                        #   in Loop: Header=BB0_6 Depth=2
	movabs	rdi, 9223372036854775804
	add	rdi, -12
	and	rdi, rcx
	mov	r9, r8
	imul	r9, r12
	add	r9, rdx
	add	r9, 32
	movabs	r10, offset .LCPI0_0
	vbroadcastss	ymm1, dword ptr [r10]
	movabs	r10, offset .LCPI0_1
	vmovaps	ymm5, ymmword ptr [r10]
	xor	r10d, r10d
	vmovaps	ymm2, ymm5
	vmovaps	ymm4, ymm1
	vmovaps	ymm0, ymm5
	vmovaps	ymm3, ymm1
.LBB0_15:                               # %vector.body662
                                        #   Parent Loop BB0_4 Depth=1
                                        #     Parent Loop BB0_6 Depth=2
                                        # =>    This Inner Loop Header: Depth=3
	vmovups	ymm6, ymmword ptr [r9 + 4*r10 - 32]
	vmovups	ymm7, ymmword ptr [r9 + 4*r10]
	vmovups	ymm8, ymmword ptr [rsi + 4*r10]
	vmovups	ymm9, ymmword ptr [rsi + 4*r10 + 32]
	vfmadd231ps	ymm5, ymm6, ymm6        # ymm5 = (ymm6 * ymm6) + ymm5
	vfmadd231ps	ymm1, ymm7, ymm7        # ymm1 = (ymm7 * ymm7) + ymm1
	vfmadd231ps	ymm2, ymm8, ymm6        # ymm2 = (ymm8 * ymm6) + ymm2
	vfmadd231ps	ymm4, ymm9, ymm7        # ymm4 = (ymm9 * ymm7) + ymm4
	vfmadd231ps	ymm0, ymm8, ymm8        # ymm0 = (ymm8 * ymm8) + ymm0
	vfmadd231ps	ymm3, ymm9, ymm9        # ymm3 = (ymm9 * ymm9) + ymm3
	add	r10, 16
	cmp	rdi, r10
	jne	.LBB0_15
# %bb.16:                               # %middle.block653
                                        #   in Loop: Header=BB0_6 Depth=2
	vaddps	ymm1, ymm1, ymm5
	vextractf128	xmm5, ymm1, 1
	vaddps	xmm1, xmm1, xmm5
	vshufpd	xmm5, xmm1, xmm1, 1             # xmm5 = xmm1[1,0]
	vaddps	xmm1, xmm1, xmm5
	vmovshdup	xmm5, xmm1              # xmm5 = xmm1[1,1,3,3]
	vaddss	xmm1, xmm1, xmm5
	vaddps	ymm2, ymm4, ymm2
	vextractf128	xmm4, ymm2, 1
	vaddps	xmm2, xmm2, xmm4
	vshufpd	xmm4, xmm2, xmm2, 1             # xmm4 = xmm2[1,0]
	vaddps	xmm2, xmm2, xmm4
	vmovshdup	xmm4, xmm2              # xmm4 = xmm2[1,1,3,3]
	vaddss	xmm2, xmm2, xmm4
	vaddps	ymm0, ymm3, ymm0
	vextractf128	xmm3, ymm0, 1
	vaddps	xmm0, xmm0, xmm3
	vshufpd	xmm3, xmm0, xmm0, 1             # xmm3 = xmm0[1,0]
	vaddps	xmm0, xmm0, xmm3
	vmovshdup	xmm3, xmm0              # xmm3 = xmm0[1,1,3,3]
	vaddss	xmm4, xmm0, xmm3
	cmp	rcx, rdi
	jne	.LBB0_18
# %bb.17:                               #   in Loop: Header=BB0_6 Depth=2
	mov	r11, qword ptr [rbp - 64]       # 8-byte Reload
	vmovaps	xmm15, xmm10
	vxorps	xmm13, xmm13, xmm13
	mov	rbx, r14
	mov	r10, qword ptr [rbp - 56]       # 8-byte Reload
	jmp	.LBB0_40
.LBB0_18:                               # %vec.epilog.iter.check686
                                        #   in Loop: Header=BB0_6 Depth=2
	test	cl, 12
	mov	r11, qword ptr [rbp - 64]       # 8-byte Reload
	vmovaps	xmm15, xmm10
	vxorps	xmm13, xmm13, xmm13
	mov	rbx, r14
	mov	r10, qword ptr [rbp - 56]       # 8-byte Reload
	je	.LBB0_22
.LBB0_19:                               # %vec.epilog.ph685
                                        #   in Loop: Header=BB0_6 Depth=2
	mov	r9, rdi
	mov	rdi, rcx
	movabs	r10, 9223372036854775804
	and	rdi, r10
	vmovaps	xmm0, xmmword ptr [rbp - 192]   # 16-byte Reload
	vblendps	xmm1, xmm0, xmm1, 1             # xmm1 = xmm1[0],xmm0[1,2,3]
	vblendps	xmm2, xmm0, xmm2, 1             # xmm2 = xmm2[0],xmm0[1,2,3]
	vblendps	xmm0, xmm0, xmm4, 1             # xmm0 = xmm4[0],xmm0[1,2,3]
	mov	r10, r8
	imul	r10, r12
	add	r10, rdx
.LBB0_20:                               # %vec.epilog.vector.body691
                                        #   Parent Loop BB0_4 Depth=1
                                        #     Parent Loop BB0_6 Depth=2
                                        # =>    This Inner Loop Header: Depth=3
	vmovups	xmm3, xmmword ptr [r10 + 4*r9]
	vmovups	xmm4, xmmword ptr [rsi + 4*r9]
	vfmadd231ps	xmm1, xmm3, xmm3        # xmm1 = (xmm3 * xmm3) + xmm1
	vfmadd231ps	xmm2, xmm4, xmm3        # xmm2 = (xmm4 * xmm3) + xmm2
	vfmadd231ps	xmm0, xmm4, xmm4        # xmm0 = (xmm4 * xmm4) + xmm0
	add	r9, 4
	cmp	rdi, r9
	jne	.LBB0_20
# %bb.21:                               # %vec.epilog.middle.block683
                                        #   in Loop: Header=BB0_6 Depth=2
	vshufpd	xmm3, xmm1, xmm1, 1             # xmm3 = xmm1[1,0]
	vaddps	xmm1, xmm1, xmm3
	vmovshdup	xmm3, xmm1              # xmm3 = xmm1[1,1,3,3]
	vaddss	xmm1, xmm1, xmm3
	vshufpd	xmm3, xmm2, xmm2, 1             # xmm3 = xmm2[1,0]
	vaddps	xmm2, xmm2, xmm3
	vmovshdup	xmm3, xmm2              # xmm3 = xmm2[1,1,3,3]
	vaddss	xmm2, xmm2, xmm3
	vshufpd	xmm3, xmm0, xmm0, 1             # xmm3 = xmm0[1,0]
	vaddps	xmm0, xmm0, xmm3
	vmovshdup	xmm3, xmm0              # xmm3 = xmm0[1,1,3,3]
	vaddss	xmm4, xmm0, xmm3
	cmp	rcx, rdi
	mov	r11, qword ptr [rbp - 64]       # 8-byte Reload
	vmovaps	xmm15, xmm10
	vxorps	xmm13, xmm13, xmm13
	mov	rbx, r14
	mov	r10, qword ptr [rbp - 56]       # 8-byte Reload
	je	.LBB0_40
.LBB0_22:                               # %L71.preheader
                                        #   in Loop: Header=BB0_6 Depth=2
	imul	r8, r12
	add	rdx, r8
.LBB0_23:                               # %L71
                                        #   Parent Loop BB0_4 Depth=1
                                        #     Parent Loop BB0_6 Depth=2
                                        # =>    This Inner Loop Header: Depth=3
	vmovss	xmm0, dword ptr [rdx + 4*rdi]   # xmm0 = mem[0],zero,zero,zero
	vmovss	xmm3, dword ptr [rsi + 4*rdi]   # xmm3 = mem[0],zero,zero,zero
	lea	r8, [rdi + 1]
	vfmadd231ss	xmm1, xmm0, xmm0        # xmm1 = (xmm0 * xmm0) + xmm1
	vfmadd231ss	xmm2, xmm3, xmm0        # xmm2 = (xmm3 * xmm0) + xmm2
	vfmadd231ss	xmm4, xmm3, xmm3        # xmm4 = (xmm3 * xmm3) + xmm4
	mov	rdi, r8
	cmp	rcx, r8
	jne	.LBB0_23
	jmp	.LBB0_40
	.p2align	4
.LBB0_79:                               # %L577
                                        #   in Loop: Header=BB0_4 Depth=1
	mov	rax, qword ptr [rbp - 152]      # 8-byte Reload
	cmp	rax, qword ptr [rbp - 144]      # 8-byte Folded Reload
	je	.LBB0_80
# %bb.3:                                # %L17thread-pre-split
                                        #   in Loop: Header=BB0_4 Depth=1
	inc	rax
	mov	rbx, qword ptr [r11 + 16]
	jmp	.LBB0_4
.LBB0_80:
	mov	rcx, qword ptr [rbp - 136]      # 8-byte Reload
.LBB0_81:                               # %L588
	mov	rax, qword ptr [rbp - 120]
	mov	qword ptr [rcx], rax
	vmovaps	xmm0, xmm15
	add	rsp, 232
	pop	rbx
	pop	r12
	pop	r13
	pop	r14
	pop	r15
	pop	rbp
	vzeroupper
	ret
.LBB0_83:                               # %L307
	mov	qword ptr [rbp - 168], r15
	movabs	rax, offset j_throw_boundserror_3917
	lea	rsi, [rbp - 168]
	mov	rdi, r11
	vzeroupper
	call	rax
.LBB0_84:                               # %L341
	mov	qword ptr [rbp - 200], r15
	mov	qword ptr [rbp - 208], rdx
	mov	qword ptr [rbp - 96], rdi
	movabs	rax, offset j_throw_boundserror_3926
	lea	rsi, [rbp - 208]
	vzeroupper
	call	rax
.LBB0_82:                               # %L47
	mov	qword ptr [rbp - 160], r15
	mov	qword ptr [rbp - 96], rdi
	movabs	rax, offset j_throw_boundserror_3917
	lea	rsi, [rbp - 160]
	vzeroupper
	call	rax
.LBB0_85:                               # %L381
	movabs	rdi, offset ".Ljl_sym#sqrt#3922.jit"
	movabs	rax, offset j_throw_complex_domainerror_3921
	vmovaps	xmm0, xmm1
	vzeroupper
	call	rax
.LBB0_87:                               # %L480
	movabs	rdi, offset ".Ljl_sym#sqrt#3922.jit"
	movabs	rax, offset j_throw_complex_domainerror_3921
	vmovaps	xmm0, xmm4
	vzeroupper
	call	rax
.LBB0_88:                               # %L486
	movabs	rdi, offset ".Ljl_sym#sqrt#3922.jit"
	movabs	rax, offset j_throw_complex_domainerror_3921
	vmovaps	xmm0, xmm5
	vzeroupper
	call	rax
.LBB0_86:                               # %L474
	movabs	rdi, offset ".Ljl_sym#sqrt#3922.jit"
	movabs	rax, offset j_throw_complex_domainerror_3921
	vmovaps	xmm0, xmm3
	vzeroupper
	call	rax
.Lfunc_end0:
	.size	julia_pass_3915, .Lfunc_end0-julia_pass_3915
                                        # -- End function
.set ".Ljl_sym#sqrt#3922.jit", 131248270530416
	.size	".Ljl_sym#sqrt#3922.jit", 8
	.section	".note.GNU-stack","",@progbits
