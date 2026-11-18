	.text
	.file	"pass"
	.section	.rodata.cst32,"aM",@progbits,32
	.p2align	5                               # -- Begin function julia_pass_1158
.LCPI0_0:
	.long	0x00000000                      # float 0
	.long	0x80000000                      # float -0
	.long	0x80000000                      # float -0
	.long	0x80000000                      # float -0
	.long	0x80000000                      # float -0
	.long	0x80000000                      # float -0
	.long	0x80000000                      # float -0
	.long	0x80000000                      # float -0
	.section	.rodata.cst4,"aM",@progbits,4
	.p2align	2
.LCPI0_1:
	.long	0x80000000                      # float -0
.LCPI0_2:
	.long	0x0c000000                      # float 9.86076131E-32
.LCPI0_3:
	.long	0x3d800000                      # float 0.0625
.LCPI0_4:
	.long	0x00800000                      # float 1.17549435E-38
.LCPI0_5:
	.long	0x7f7fffff                      # float 3.40282347E+38
.LCPI0_6:
	.long	0x3f800000                      # float 1
	.text
	.globl	julia_pass_1158
	.p2align	4, 0x90
	.type	julia_pass_1158,@function
julia_pass_1158:                        # @julia_pass_1158
# %bb.0:                                # %top
	push	rbp
	mov	rbp, rsp
	push	r15
	push	r14
	push	r13
	push	r12
	push	rbx
	sub	rsp, 152
	vxorps	xmm0, xmm0, xmm0
	#APP
	mov	rax, qword ptr fs:[0]
	#NO_APP
	vxorps	xmm7, xmm7, xmm7
	vmovaps	xmmword ptr [rbp - 96], xmm0
	mov	qword ptr [rbp - 80], 0
	mov	rcx, qword ptr [rax - 8]
	mov	qword ptr [rbp - 96], 4
	mov	rax, qword ptr [rcx]
	mov	qword ptr [rbp - 88], rax
	lea	rax, [rbp - 96]
	mov	qword ptr [rcx], rax
	xor	eax, eax
	test	rdx, rdx
	cmovg	rax, rdx
	mov	qword ptr [rbp - 112], rax      # 8-byte Spill
	jle	.LBB0_73
# %bb.1:                                # %L17.preheader
	mov	rdx, qword ptr [rsi + 8]
	mov	r15, rsi
	test	rdx, rdx
	je	.LBB0_73
# %bb.2:                                # %L17.preheader350
	movabs	rsi, offset .LCPI0_1
	mov	qword ptr [rbp - 104], rcx      # 8-byte Spill
	movabs	rcx, offset .LCPI0_0
	mov	r12, qword ptr [rdi]
	mov	rbx, rdi
	vxorps	xmm10, xmm10, xmm10
	mov	eax, 1
	vxorps	xmm7, xmm7, xmm7
	mov	qword ptr [rbp - 48], rdi       # 8-byte Spill
	vbroadcastss	ymm0, dword ptr [rsi]
	vmovaps	ymm1, ymmword ptr [rcx]
	vmovups	ymmword ptr [rbp - 160], ymm1   # 32-byte Spill
	vmovups	ymmword ptr [rbp - 192], ymm0   # 32-byte Spill
	.p2align	4, 0x90
.LBB0_4:                                # %L17
                                        # =>This Loop Header: Depth=1
                                        #     Child Loop BB0_6 Depth 2
                                        #       Child Loop BB0_16 Depth 3
                                        #       Child Loop BB0_19 Depth 3
                                        #       Child Loop BB0_25 Depth 3
                                        #       Child Loop BB0_28 Depth 3
                                        #       Child Loop BB0_41 Depth 3
                                        #       Child Loop BB0_44 Depth 3
	test	rdx, rdx
	mov	qword ptr [rbp - 120], rax      # 8-byte Spill
	je	.LBB0_71
# %bb.5:                                # %L31.preheader
                                        #   in Loop: Header=BB0_4 Depth=1
	mov	r14d, 1
	xor	r13d, r13d
	mov	qword ptr [rbp - 128], rdx      # 8-byte Spill
	jmp	.LBB0_6
	.p2align	4, 0x90
.LBB0_69:                               # %L327
                                        #   in Loop: Header=BB0_6 Depth=2
	mov	rdi, rbx
	vmovaps	xmm0, xmm2
	mov	rsi, r14
	movabs	rax, offset j__sqrt_offrange_step_1164
	mov	qword ptr [rbp - 80], r12
	vzeroupper
	call	rax
	vxorps	xmm10, xmm10, xmm10
	vmovaps	xmm3, xmm0
.LBB0_70:                               # %L329
                                        #   in Loop: Header=BB0_6 Depth=2
	vmovss	xmm7, dword ptr [rbp - 64]      # 4-byte Reload
                                        # xmm7 = mem[0],zero,zero,zero
	add	r13, 4
	cmp	r14, qword ptr [rbp - 128]      # 8-byte Folded Reload
	lea	r14, [r14 + 1]
	vaddss	xmm7, xmm7, xmm3
	je	.LBB0_71
.LBB0_6:                                # %L31
                                        #   Parent Loop BB0_4 Depth=1
                                        # =>  This Loop Header: Depth=2
                                        #       Child Loop BB0_16 Depth 3
                                        #       Child Loop BB0_19 Depth 3
                                        #       Child Loop BB0_25 Depth 3
                                        #       Child Loop BB0_28 Depth 3
                                        #       Child Loop BB0_41 Depth 3
                                        #       Child Loop BB0_44 Depth 3
	mov	rdi, qword ptr [r12 + 32]
	lea	r9, [r14 - 1]
	cmp	r9, qword ptr [rdi + 8]
	jae	.LBB0_7
# %bb.10:                               # %idxend
                                        #   in Loop: Header=BB0_6 Depth=2
	mov	rax, qword ptr [rdi]
	mov	rsi, qword ptr [r12]
	vmovss	xmm0, dword ptr [rax + 4*r14 - 4] # xmm0 = mem[0],zero,zero,zero
	mov	rax, qword ptr [r12 + 24]
	vucomiss	xmm0, xmm0
	mov	rcx, qword ptr [rax + 8]
	jp	.LBB0_11
# %bb.20:                               # %L83
                                        #   in Loop: Header=BB0_6 Depth=2
	test	rcx, rcx
	je	.LBB0_21
# %bb.22:                               # %L96.lr.ph
                                        #   in Loop: Header=BB0_6 Depth=2
	mov	rdx, qword ptr [rsi]
	mov	r8, qword ptr [rsi + 24]
	mov	rsi, qword ptr [rax]
	cmp	rcx, 16
	jae	.LBB0_24
# %bb.23:                               #   in Loop: Header=BB0_6 Depth=2
	vxorps	xmm5, xmm5, xmm5
	xor	edi, edi
	vxorps	xmm4, xmm4, xmm4
	jmp	.LBB0_27
	.p2align	4, 0x90
.LBB0_21:                               #   in Loop: Header=BB0_6 Depth=2
	vxorps	xmm4, xmm4, xmm4
	vxorps	xmm5, xmm5, xmm5
	jmp	.LBB0_29
	.p2align	4, 0x90
.LBB0_24:                               # %vector.ph269
                                        #   in Loop: Header=BB0_6 Depth=2
	mov	rdi, rcx
	movabs	rax, 9223372036854775792
	vmovups	ymm3, ymmword ptr [rbp - 160]   # 32-byte Reload
	vmovups	ymm4, ymmword ptr [rbp - 192]   # 32-byte Reload
	xor	ebx, ebx
	and	rdi, rax
	mov	rax, r8
	imul	rax, r13
	vmovaps	ymm1, ymm3
	vmovaps	ymm2, ymm4
	add	rax, rdx
	add	rax, 32
	.p2align	4, 0x90
.LBB0_25:                               # %vector.body274
                                        #   Parent Loop BB0_4 Depth=1
                                        #     Parent Loop BB0_6 Depth=2
                                        # =>    This Inner Loop Header: Depth=3
	vmovups	ymm5, ymmword ptr [rsi + 4*rbx]
	vmovups	ymm6, ymmword ptr [rsi + 4*rbx + 32]
	vfmadd231ps	ymm1, ymm5, ymmword ptr [rax + 4*rbx - 32] # ymm1 = (ymm5 * mem) + ymm1
	vfmadd231ps	ymm2, ymm6, ymmword ptr [rax + 4*rbx] # ymm2 = (ymm6 * mem) + ymm2
	add	rbx, 16
	vfmadd231ps	ymm3, ymm5, ymm5        # ymm3 = (ymm5 * ymm5) + ymm3
	vfmadd231ps	ymm4, ymm6, ymm6        # ymm4 = (ymm6 * ymm6) + ymm4
	cmp	rdi, rbx
	jne	.LBB0_25
# %bb.26:                               # %middle.block266
                                        #   in Loop: Header=BB0_6 Depth=2
	vaddps	ymm3, ymm4, ymm3
	vaddps	ymm1, ymm2, ymm1
	mov	rbx, qword ptr [rbp - 48]       # 8-byte Reload
	cmp	rcx, rdi
	vextractf128	xmm2, ymm3, 1
	vaddps	xmm2, xmm3, xmm2
	vextractf128	xmm3, ymm1, 1
	vaddps	xmm1, xmm1, xmm3
	vpermilpd	xmm3, xmm2, 1           # xmm3 = xmm2[1,0]
	vpermilpd	xmm4, xmm1, 1           # xmm4 = xmm1[1,0]
	vaddps	xmm2, xmm2, xmm3
	vaddps	xmm1, xmm1, xmm4
	vmovshdup	xmm3, xmm2              # xmm3 = xmm2[1,1,3,3]
	vmovshdup	xmm5, xmm1              # xmm5 = xmm1[1,1,3,3]
	vaddss	xmm4, xmm2, xmm3
	vaddss	xmm5, xmm1, xmm5
	je	.LBB0_29
.LBB0_27:                               # %scalar.ph267
                                        #   in Loop: Header=BB0_6 Depth=2
	imul	r8, r13
	add	rdx, r8
	.p2align	4, 0x90
.LBB0_28:                               # %L96
                                        #   Parent Loop BB0_4 Depth=1
                                        #     Parent Loop BB0_6 Depth=2
                                        # =>    This Inner Loop Header: Depth=3
	vmovss	xmm1, dword ptr [rsi + 4*rdi]   # xmm1 = mem[0],zero,zero,zero
	vfmadd231ss	xmm5, xmm1, dword ptr [rdx + 4*rdi] # xmm5 = (xmm1 * mem) + xmm5
	add	rdi, 1
	vfmadd231ss	xmm4, xmm1, xmm1        # xmm4 = (xmm1 * xmm1) + xmm4
	cmp	rcx, rdi
	jne	.LBB0_28
.LBB0_29:                               # %L124
                                        #   in Loop: Header=BB0_6 Depth=2
	cmp	r9, qword ptr [r15 + 8]
	jae	.LBB0_30
# %bb.76:                               # %idxend46
                                        #   in Loop: Header=BB0_6 Depth=2
	vsubss	xmm1, xmm0, xmm0
	mov	rax, qword ptr [r15]
	vmovss	dword ptr [rbp - 64], xmm7      # 4-byte Spill
	vucomiss	xmm1, xmm1
	vmovss	xmm2, dword ptr [rax + 4*r14 - 4] # xmm2 = mem[0],zero,zero,zero
	jp	.LBB0_69
# %bb.77:                               # %idxend46
                                        #   in Loop: Header=BB0_6 Depth=2
	mov	rcx, qword ptr [rbx]
	movabs	rsi, offset .LCPI0_2
	mov	rdx, qword ptr [rcx + 24]
	mov	rax, qword ptr [rdx + 8]
	vcvtsi2ss	xmm1, xmm13, rax
	vmulss	xmm7, xmm1, dword ptr [rsi]
	vucomiss	xmm0, xmm7
	jb	.LBB0_69
# %bb.78:                               # %idxend46
                                        #   in Loop: Header=BB0_6 Depth=2
	vsubss	xmm1, xmm4, xmm4
	vucomiss	xmm1, xmm1
	jp	.LBB0_69
# %bb.79:                               # %idxend46
                                        #   in Loop: Header=BB0_6 Depth=2
	vucomiss	xmm4, xmm7
	jb	.LBB0_69
# %bb.33:                               # %L144
                                        #   in Loop: Header=BB0_6 Depth=2
	vucomiss	xmm10, xmm0
	ja	.LBB0_80
# %bb.34:                               # %L150
                                        #   in Loop: Header=BB0_6 Depth=2
	vsqrtss	xmm1, xmm0, xmm0
	vmovss	xmm11, dword ptr [rbx + 8]      # xmm11 = mem[0],zero,zero,zero
	vxorps	xmm3, xmm3, xmm3
	vucomiss	xmm11, xmm1
	jae	.LBB0_70
# %bb.35:                               # %L155
                                        #   in Loop: Header=BB0_6 Depth=2
	vdivss	xmm6, xmm5, xmm0
	movabs	rsi, offset .LCPI0_3
	vmulss	xmm3, xmm4, dword ptr [rsi]
	vmulss	xmm0, xmm5, xmm6
	vsubss	xmm0, xmm4, xmm0
	vucomiss	xmm3, xmm0
	jbe	.LBB0_48
# %bb.36:                               # %L162
                                        #   in Loop: Header=BB0_6 Depth=2
	test	rax, rax
	je	.LBB0_37
# %bb.38:                               # %L176.lr.ph
                                        #   in Loop: Header=BB0_6 Depth=2
	mov	rsi, qword ptr [rcx]
	mov	rcx, qword ptr [rdx]
	cmp	rax, 16
	mov	rdx, qword ptr [rsi]
	mov	r8, qword ptr [rsi + 24]
	jae	.LBB0_40
# %bb.39:                               #   in Loop: Header=BB0_6 Depth=2
	vxorps	xmm0, xmm0, xmm0
	xor	esi, esi
	jmp	.LBB0_43
.LBB0_37:                               #   in Loop: Header=BB0_6 Depth=2
	vxorps	xmm0, xmm0, xmm0
	jmp	.LBB0_45
.LBB0_40:                               # %vector.ph
                                        #   in Loop: Header=BB0_6 Depth=2
	mov	rsi, rax
	movabs	rdi, 9223372036854775792
	vbroadcastss	ymm3, xmm6
	and	rsi, rdi
	movabs	rdi, offset .LCPI0_1
	vbroadcastss	ymm0, dword ptr [rdi]
	mov	rdi, r8
	imul	rdi, r13
	lea	rbx, [rdx + rdi + 32]
	movabs	rdi, offset .LCPI0_0
	vmovaps	ymm4, ymmword ptr [rdi]
	xor	edi, edi
	.p2align	4, 0x90
.LBB0_41:                               # %vector.body
                                        #   Parent Loop BB0_4 Depth=1
                                        #     Parent Loop BB0_6 Depth=2
                                        # =>    This Inner Loop Header: Depth=3
	vmulps	ymm5, ymm3, ymmword ptr [rbx + 4*rdi - 32]
	vmulps	ymm8, ymm3, ymmword ptr [rbx + 4*rdi]
	vmovups	ymm9, ymmword ptr [rcx + 4*rdi]
	vmovups	ymm12, ymmword ptr [rcx + 4*rdi + 32]
	add	rdi, 16
	cmp	rsi, rdi
	vsubps	ymm5, ymm9, ymm5
	vsubps	ymm8, ymm12, ymm8
	vfmadd231ps	ymm4, ymm5, ymm5        # ymm4 = (ymm5 * ymm5) + ymm4
	vfmadd231ps	ymm0, ymm8, ymm8        # ymm0 = (ymm8 * ymm8) + ymm0
	jne	.LBB0_41
# %bb.42:                               # %middle.block
                                        #   in Loop: Header=BB0_6 Depth=2
	vaddps	ymm0, ymm0, ymm4
	mov	rbx, qword ptr [rbp - 48]       # 8-byte Reload
	cmp	rax, rsi
	vextractf128	xmm3, ymm0, 1
	vaddps	xmm0, xmm0, xmm3
	vpermilpd	xmm3, xmm0, 1           # xmm3 = xmm0[1,0]
	vaddps	xmm0, xmm0, xmm3
	vmovshdup	xmm3, xmm0              # xmm3 = xmm0[1,1,3,3]
	vaddss	xmm0, xmm0, xmm3
	je	.LBB0_45
.LBB0_43:                               # %scalar.ph
                                        #   in Loop: Header=BB0_6 Depth=2
	imul	r8, r13
	add	rdx, r8
	.p2align	4, 0x90
.LBB0_44:                               # %L176
                                        #   Parent Loop BB0_4 Depth=1
                                        #     Parent Loop BB0_6 Depth=2
                                        # =>    This Inner Loop Header: Depth=3
	vmulss	xmm3, xmm6, dword ptr [rdx + 4*rsi]
	vmovss	xmm4, dword ptr [rcx + 4*rsi]   # xmm4 = mem[0],zero,zero,zero
	add	rsi, 1
	cmp	rax, rsi
	vsubss	xmm3, xmm4, xmm3
	vfmadd231ss	xmm0, xmm3, xmm3        # xmm0 = (xmm3 * xmm3) + xmm0
	jne	.LBB0_44
.LBB0_45:                               # %L199
                                        #   in Loop: Header=BB0_6 Depth=2
	vucomiss	xmm0, xmm7
	jb	.LBB0_47
# %bb.46:                               # %L199
                                        #   in Loop: Header=BB0_6 Depth=2
	vsubss	xmm3, xmm0, xmm0
	vucomiss	xmm3, xmm3
	jp	.LBB0_47
.LBB0_48:                               # %L210
                                        #   in Loop: Header=BB0_6 Depth=2
	vucomiss	xmm10, xmm0
	ja	.LBB0_81
# %bb.49:                               # %L215
                                        #   in Loop: Header=BB0_6 Depth=2
	vsubss	xmm3, xmm1, xmm11
	movabs	rax, offset .LCPI0_4
	vucomiss	xmm10, xmm3
	ja	.LBB0_82
# %bb.50:                               # %L222
                                        #   in Loop: Header=BB0_6 Depth=2
	vaddss	xmm4, xmm11, xmm1
	vucomiss	xmm10, xmm4
	ja	.LBB0_83
# %bb.51:                               # %L229
                                        #   in Loop: Header=BB0_6 Depth=2
	vsqrtss	xmm3, xmm3, xmm3
	vsqrtss	xmm4, xmm4, xmm4
	vsqrtss	xmm5, xmm0, xmm0
	vmulss	xmm3, xmm3, xmm4
	vucomiss	xmm5, xmm10
	vaddss	xmm4, xmm6, xmm2
	vmulss	xmm3, xmm1, xmm3
	vdivss	xmm0, xmm5, xmm3
	jne	.LBB0_56
	jnp	.LBB0_52
.LBB0_56:                               # %L238
                                        #   in Loop: Header=BB0_6 Depth=2
	vucomiss	xmm3, dword ptr [rax]
	jb	.LBB0_61
# %bb.57:                               # %L238
                                        #   in Loop: Header=BB0_6 Depth=2
	vucomiss	xmm0, dword ptr [rax]
	jb	.LBB0_61
# %bb.58:                               # %L238
                                        #   in Loop: Header=BB0_6 Depth=2
	movabs	rcx, offset .LCPI0_5
	vmovss	xmm3, dword ptr [rcx]           # xmm3 = mem[0],zero,zero,zero
	vucomiss	xmm3, xmm0
	jb	.LBB0_61
# %bb.59:                               # %L238
                                        #   in Loop: Header=BB0_6 Depth=2
	vmulss	xmm2, xmm11, xmm0
	vucomiss	xmm2, dword ptr [rax]
	jb	.LBB0_61
# %bb.60:                               # %L238
                                        #   in Loop: Header=BB0_6 Depth=2
	vucomiss	xmm3, xmm2
	jb	.LBB0_61
# %bb.53:                               # %L258
                                        #   in Loop: Header=BB0_6 Depth=2
	vucomiss	xmm2, dword ptr [rax]
	jae	.LBB0_54
	jmp	.LBB0_62
.LBB0_52:                               # %L229.L258_crit_edge
                                        #   in Loop: Header=BB0_6 Depth=2
	vmulss	xmm2, xmm11, xmm0
	vucomiss	xmm2, dword ptr [rax]
	jb	.LBB0_62
.LBB0_54:                               # %L258
                                        #   in Loop: Header=BB0_6 Depth=2
	movabs	rax, offset .LCPI0_5
	vmovss	xmm1, dword ptr [rax]           # xmm1 = mem[0],zero,zero,zero
	vucomiss	xmm1, xmm2
	jb	.LBB0_62
# %bb.55:                               # %L270
                                        #   in Loop: Header=BB0_6 Depth=2
	movabs	rax, offset .LCPI0_1
	vbroadcastss	xmm0, dword ptr [rax]
	vxorps	xmm0, xmm2, xmm0
	vmaxss	xmm0, xmm4, xmm0
	vminss	xmm0, xmm0, xmm2
	vsubss	xmm0, xmm4, xmm0
	vaddss	xmm3, xmm10, xmm0
	jmp	.LBB0_70
.LBB0_62:                               # %L294
                                        #   in Loop: Header=BB0_6 Depth=2
	movabs	rax, offset .LCPI0_6
	vmovaps	xmm1, xmm11
	mov	qword ptr [rbp - 80], r12
	vmovss	dword ptr [rbp - 56], xmm0      # 4-byte Spill
	vmovss	dword ptr [rbp - 60], xmm11     # 4-byte Spill
	vmovss	dword ptr [rbp - 52], xmm4      # 4-byte Spill
	vmovss	xmm2, dword ptr [rax]           # xmm2 = mem[0],zero,zero,zero
	movabs	rax, offset j__exceptional_product_1162
	vzeroupper
	call	rax
	vmovss	xmm4, dword ptr [rbp - 52]      # 4-byte Reload
                                        # xmm4 = mem[0],zero,zero,zero
	vxorps	xmm1, xmm1, xmm1
	vsubss	xmm2, xmm4, xmm0
	vmovd	eax, xmm2
	vmovaps	xmm3, xmm2
	test	eax, eax
	jns	.LBB0_64
# %bb.63:                               # %L294
                                        #   in Loop: Header=BB0_6 Depth=2
	vxorps	xmm3, xmm3, xmm3
.LBB0_64:                               # %L294
                                        #   in Loop: Header=BB0_6 Depth=2
	vaddss	xmm0, xmm4, xmm0
	vxorps	xmm4, xmm4, xmm4
	vmovd	eax, xmm0
	test	eax, eax
	jns	.LBB0_66
# %bb.65:                               # %L294
                                        #   in Loop: Header=BB0_6 Depth=2
	vmovaps	xmm4, xmm0
.LBB0_66:                               # %L294
                                        #   in Loop: Header=BB0_6 Depth=2
	vcmpordss	xmm5, xmm2, xmm2
	vcmpordss	xmm6, xmm0, xmm0
	vxorps	xmm10, xmm10, xmm10
	vblendvps	xmm2, xmm2, xmm3, xmm5
	vblendvps	xmm0, xmm0, xmm4, xmm6
	vaddss	xmm0, xmm2, xmm0
	vmovd	xmm2, dword ptr [rbp - 60]      # 4-byte Folded Reload
                                        # xmm2 = mem[0],zero,zero,zero
	vmovd	eax, xmm2
	vmovaps	xmm2, xmm0
	and	eax, 2147483647
	cmp	eax, 2139095040
	jne	.LBB0_68
# %bb.67:                               # %L294
                                        #   in Loop: Header=BB0_6 Depth=2
	vxorps	xmm2, xmm2, xmm2
.LBB0_68:                               # %L294
                                        #   in Loop: Header=BB0_6 Depth=2
	vcmpnless	xmm1, xmm1, dword ptr [rbp - 56] # 4-byte Folded Reload
	vblendvps	xmm3, xmm2, xmm0, xmm1
	jmp	.LBB0_70
.LBB0_47:                               # %L208
                                        #   in Loop: Header=BB0_6 Depth=2
	mov	rdi, rbx
	vmovaps	xmm0, xmm2
	mov	rsi, r14
	movabs	rax, offset j__sqrt_offrange_step_1164
	mov	qword ptr [rbp - 80], r12
	vzeroupper
	call	rax
	vxorps	xmm10, xmm10, xmm10
	vmovaps	xmm3, xmm0
	jmp	.LBB0_70
.LBB0_61:                               # %L255
                                        #   in Loop: Header=BB0_6 Depth=2
	vcvtss2sd	xmm3, xmm5, xmm5
	vmovaps	xmm0, xmm4
	vmovaps	xmm2, xmm11
	xor	edi, edi
	movabs	rax, offset j__sqrt_band_step_1163
	mov	qword ptr [rbp - 80], r12
	vzeroupper
	call	rax
	vxorps	xmm10, xmm10, xmm10
	vmovaps	xmm3, xmm0
	jmp	.LBB0_70
.LBB0_11:                               # %L40
                                        #   in Loop: Header=BB0_6 Depth=2
	test	rcx, rcx
	je	.LBB0_12
# %bb.13:                               # %L54.lr.ph
                                        #   in Loop: Header=BB0_6 Depth=2
	mov	rdx, qword ptr [rsi]
	mov	r8, qword ptr [rsi + 24]
	mov	rsi, qword ptr [rax]
	cmp	rcx, 8
	jae	.LBB0_15
# %bb.14:                               #   in Loop: Header=BB0_6 Depth=2
	vxorps	xmm0, xmm0, xmm0
	xor	edi, edi
	vxorps	xmm5, xmm5, xmm5
	vxorps	xmm4, xmm4, xmm4
	jmp	.LBB0_18
.LBB0_12:                               #   in Loop: Header=BB0_6 Depth=2
	vxorps	xmm4, xmm4, xmm4
	vxorps	xmm5, xmm5, xmm5
	vxorps	xmm0, xmm0, xmm0
	jmp	.LBB0_29
.LBB0_15:                               # %vector.ph292
                                        #   in Loop: Header=BB0_6 Depth=2
	movabs	rax, 9223372036854775792
	movabs	rbx, offset .LCPI0_0
	lea	rdi, [rax + 8]
	mov	rax, r8
	vmovaps	ymm0, ymmword ptr [rbx]
	xor	ebx, ebx
	imul	rax, r13
	and	rdi, rcx
	vmovaps	ymm1, ymm0
	vmovaps	ymm2, ymm0
	add	rax, rdx
.LBB0_16:                               # %vector.body297
                                        #   Parent Loop BB0_4 Depth=1
                                        #     Parent Loop BB0_6 Depth=2
                                        # =>    This Inner Loop Header: Depth=3
	vmovups	ymm3, ymmword ptr [rax + 4*rbx]
	vmovups	ymm4, ymmword ptr [rsi + 4*rbx]
	add	rbx, 8
	cmp	rdi, rbx
	vfmadd231ps	ymm0, ymm3, ymm3        # ymm0 = (ymm3 * ymm3) + ymm0
	vfmadd231ps	ymm1, ymm4, ymm3        # ymm1 = (ymm4 * ymm3) + ymm1
	vfmadd231ps	ymm2, ymm4, ymm4        # ymm2 = (ymm4 * ymm4) + ymm2
	jne	.LBB0_16
# %bb.17:                               # %middle.block289
                                        #   in Loop: Header=BB0_6 Depth=2
	vextractf128	xmm3, ymm2, 1
	mov	rbx, qword ptr [rbp - 48]       # 8-byte Reload
	cmp	rcx, rdi
	vaddps	xmm2, xmm2, xmm3
	vextractf128	xmm3, ymm1, 1
	vaddps	xmm1, xmm1, xmm3
	vextractf128	xmm3, ymm0, 1
	vaddps	xmm0, xmm0, xmm3
	vpermilpd	xmm3, xmm2, 1           # xmm3 = xmm2[1,0]
	vaddps	xmm2, xmm2, xmm3
	vpermilpd	xmm3, xmm1, 1           # xmm3 = xmm1[1,0]
	vpermilpd	xmm4, xmm0, 1           # xmm4 = xmm0[1,0]
	vaddps	xmm1, xmm1, xmm3
	vaddps	xmm0, xmm0, xmm4
	vmovshdup	xmm3, xmm2              # xmm3 = xmm2[1,1,3,3]
	vaddss	xmm4, xmm2, xmm3
	vmovshdup	xmm2, xmm1              # xmm2 = xmm1[1,1,3,3]
	vmovshdup	xmm3, xmm0              # xmm3 = xmm0[1,1,3,3]
	vaddss	xmm5, xmm1, xmm2
	vaddss	xmm0, xmm0, xmm3
	je	.LBB0_29
.LBB0_18:                               # %scalar.ph290
                                        #   in Loop: Header=BB0_6 Depth=2
	imul	r8, r13
	add	rdx, r8
.LBB0_19:                               # %L54
                                        #   Parent Loop BB0_4 Depth=1
                                        #     Parent Loop BB0_6 Depth=2
                                        # =>    This Inner Loop Header: Depth=3
	vmovss	xmm1, dword ptr [rdx + 4*rdi]   # xmm1 = mem[0],zero,zero,zero
	vmovss	xmm2, dword ptr [rsi + 4*rdi]   # xmm2 = mem[0],zero,zero,zero
	add	rdi, 1
	cmp	rcx, rdi
	vfmadd231ss	xmm0, xmm1, xmm1        # xmm0 = (xmm1 * xmm1) + xmm0
	vfmadd231ss	xmm5, xmm2, xmm1        # xmm5 = (xmm2 * xmm1) + xmm5
	vfmadd231ss	xmm4, xmm2, xmm2        # xmm4 = (xmm2 * xmm2) + xmm4
	jne	.LBB0_19
	jmp	.LBB0_29
	.p2align	4, 0x90
.LBB0_71:                               # %L342
                                        #   in Loop: Header=BB0_4 Depth=1
	mov	rax, qword ptr [rbp - 120]      # 8-byte Reload
	cmp	rax, qword ptr [rbp - 112]      # 8-byte Folded Reload
	je	.LBB0_72
# %bb.3:                                # %L17thread-pre-split
                                        #   in Loop: Header=BB0_4 Depth=1
	mov	rdx, qword ptr [r15 + 8]
	add	rax, 1
	jmp	.LBB0_4
.LBB0_72:
	mov	rcx, qword ptr [rbp - 104]      # 8-byte Reload
.LBB0_73:                               # %L353
	mov	rax, qword ptr [rbp - 88]
	vmovaps	xmm0, xmm7
	mov	qword ptr [rcx], rax
	lea	rsp, [rbp - 40]
	pop	rbx
	pop	r12
	pop	r13
	pop	r14
	pop	r15
	pop	rbp
	vzeroupper
	ret
.LBB0_7:                                # %oob
	mov	rsi, rsp
	mov	eax, 16
	sub	rsi, rax
	cmp	rsi, rsp
	jge	.LBB0_74
.LBB0_9:                                # %oob
                                        # =>This Inner Loop Header: Depth=1
	xor	qword ptr [rsp], 0
	sub	rsp, 4096
	cmp	rsi, rsp
	jl	.LBB0_9
.LBB0_74:                               # %oob
	mov	rsp, rsi
	movabs	rax, offset ijl_bounds_error_ints
	mov	edx, 1
	mov	qword ptr [rsi], r14
	vzeroupper
	call	rax
.LBB0_30:                               # %oob44
	mov	rsi, rsp
	mov	eax, 16
	sub	rsi, rax
	cmp	rsi, rsp
	jge	.LBB0_75
.LBB0_32:                               # %oob44
                                        # =>This Inner Loop Header: Depth=1
	xor	qword ptr [rsp], 0
	sub	rsp, 4096
	cmp	rsi, rsp
	jl	.LBB0_32
.LBB0_75:                               # %oob44
	mov	rsp, rsi
	movabs	rax, offset ijl_bounds_error_ints
	mov	edx, 1
	mov	rdi, r15
	mov	qword ptr [rsi], r14
	vzeroupper
	call	rax
.LBB0_80:                               # %L148
	movabs	rax, offset j_throw_complex_domainerror_1161
	movabs	rdi, 123609136802320
	vzeroupper
	call	rax
.LBB0_81:                               # %L213
	movabs	rax, offset j_throw_complex_domainerror_1161
	movabs	rdi, 123609136802320
	vzeroupper
	call	rax
.LBB0_82:                               # %L220
	movabs	rax, offset j_throw_complex_domainerror_1161
	movabs	rdi, 123609136802320
	vmovaps	xmm0, xmm3
	vzeroupper
	call	rax
.LBB0_83:                               # %L227
	movabs	rax, offset j_throw_complex_domainerror_1161
	movabs	rdi, 123609136802320
	vmovaps	xmm0, xmm4
	vzeroupper
	call	rax
.Lfunc_end0:
	.size	julia_pass_1158, .Lfunc_end0-julia_pass_1158
                                        # -- End function
	.section	".note.GNU-stack","",@progbits
