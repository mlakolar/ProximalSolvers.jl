	.text
	.file	"pass"
	.section	.rodata.cst32,"aM",@progbits,32
	.p2align	5                               # -- Begin function julia_pass_1889
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
	.text
	.globl	julia_pass_1889
	.p2align	4, 0x90
	.type	julia_pass_1889,@function
julia_pass_1889:                        # @julia_pass_1889
# %bb.0:                                # %top
	push	rbp
	mov	rbp, rsp
	push	r15
	push	r14
	push	r13
	push	r12
	push	rbx
	sub	rsp, 168
	vxorps	xmm0, xmm0, xmm0
	#APP
	mov	rax, qword ptr fs:[0]
	#NO_APP
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
	mov	qword ptr [rbp - 128], rax      # 8-byte Spill
	jle	.LBB0_1
# %bb.2:                                # %L17.preheader
	mov	r10, qword ptr [rsi + 8]
	mov	r11, rsi
	test	r10, r10
	je	.LBB0_3
# %bb.4:                                # %L17.preheader454
	movabs	rdx, offset .LCPI0_1
	mov	qword ptr [rbp - 120], rcx      # 8-byte Spill
	movabs	rcx, offset .LCPI0_0
	mov	r13, qword ptr [rdi]
	mov	rbx, rdi
	vxorps	xmm11, xmm11, xmm11
	mov	eax, 1
	vxorps	xmm10, xmm10, xmm10
	mov	qword ptr [rbp - 64], rdi       # 8-byte Spill
	vbroadcastss	ymm0, dword ptr [rdx]
	vmovaps	ymm1, ymmword ptr [rcx]
                                        # implicit-def: $rcx
                                        # kill: killed $rcx
                                        # implicit-def: $rcx
                                        # kill: killed $rcx
	vmovups	ymmword ptr [rbp - 176], ymm1   # 32-byte Spill
	vmovups	ymmword ptr [rbp - 208], ymm0   # 32-byte Spill
	.p2align	4, 0x90
.LBB0_6:                                # %L17
                                        # =>This Loop Header: Depth=1
                                        #     Child Loop BB0_8 Depth 2
                                        #       Child Loop BB0_18 Depth 3
                                        #       Child Loop BB0_21 Depth 3
                                        #       Child Loop BB0_27 Depth 3
                                        #       Child Loop BB0_30 Depth 3
                                        #       Child Loop BB0_47 Depth 3
                                        #       Child Loop BB0_44 Depth 3
	test	r10, r10
	mov	qword ptr [rbp - 136], rax      # 8-byte Spill
	je	.LBB0_60
# %bb.7:                                # %L31.preheader
                                        #   in Loop: Header=BB0_6 Depth=1
	mov	r14d, 1
	xor	r12d, r12d
	jmp	.LBB0_8
	.p2align	4, 0x90
.LBB0_58:                               # %L291
                                        #   in Loop: Header=BB0_8 Depth=2
	mov	rdi, rbx
	mov	rsi, r14
	movabs	rax, offset j__sqrt_cold_1895
	mov	qword ptr [rbp - 144], r14      # 8-byte Spill
	mov	r14, r12
	mov	r12, rbx
	mov	qword ptr [rbp - 80], r13
	vmovss	dword ptr [rbp - 68], xmm10     # 4-byte Spill
	mov	r15, r10
	mov	rbx, r11
	vzeroupper
	call	rax
	mov	r11, rbx
	mov	rbx, r12
	mov	r12, r14
	mov	r14, qword ptr [rbp - 144]      # 8-byte Reload
	vmovss	xmm10, dword ptr [rbp - 68]     # 4-byte Reload
                                        # xmm10 = mem[0],zero,zero,zero
	mov	r10, r15
	vxorps	xmm11, xmm11, xmm11
	vmovaps	xmm2, xmm0
.LBB0_59:                               # %L295
                                        #   in Loop: Header=BB0_8 Depth=2
	vaddss	xmm10, xmm10, xmm2
	add	r12, 4
	cmp	r14, r10
	lea	r14, [r14 + 1]
	je	.LBB0_60
.LBB0_8:                                # %L31
                                        #   Parent Loop BB0_6 Depth=1
                                        # =>  This Loop Header: Depth=2
                                        #       Child Loop BB0_18 Depth 3
                                        #       Child Loop BB0_21 Depth 3
                                        #       Child Loop BB0_27 Depth 3
                                        #       Child Loop BB0_30 Depth 3
                                        #       Child Loop BB0_47 Depth 3
                                        #       Child Loop BB0_44 Depth 3
	mov	rdi, qword ptr [r13 + 32]
	lea	r9, [r14 - 1]
	cmp	r9, qword ptr [rdi + 8]
	jae	.LBB0_9
# %bb.12:                               # %idxend
                                        #   in Loop: Header=BB0_8 Depth=2
	mov	rax, qword ptr [rdi]
	mov	rsi, qword ptr [r13]
	vmovss	xmm1, dword ptr [rax + 4*r14 - 4] # xmm1 = mem[0],zero,zero,zero
	mov	rax, qword ptr [r13 + 24]
	vucomiss	xmm1, xmm1
	mov	rcx, qword ptr [rax + 8]
	jp	.LBB0_13
# %bb.22:                               # %L83
                                        #   in Loop: Header=BB0_8 Depth=2
	test	rcx, rcx
	je	.LBB0_23
# %bb.24:                               # %L96.lr.ph
                                        #   in Loop: Header=BB0_8 Depth=2
	mov	rdx, qword ptr [rsi]
	mov	r8, qword ptr [rsi + 24]
	mov	rsi, qword ptr [rax]
	cmp	rcx, 16
	jae	.LBB0_26
# %bb.25:                               #   in Loop: Header=BB0_8 Depth=2
	vxorps	xmm7, xmm7, xmm7
	xor	edi, edi
	vxorps	xmm3, xmm3, xmm3
	jmp	.LBB0_29
	.p2align	4, 0x90
.LBB0_23:                               #   in Loop: Header=BB0_8 Depth=2
	vxorps	xmm3, xmm3, xmm3
	vxorps	xmm7, xmm7, xmm7
	jmp	.LBB0_31
	.p2align	4, 0x90
.LBB0_26:                               # %vector.ph367
                                        #   in Loop: Header=BB0_8 Depth=2
	mov	rdi, rcx
	movabs	rax, 9223372036854775792
	vmovups	ymm3, ymmword ptr [rbp - 176]   # 32-byte Reload
	vmovups	ymm4, ymmword ptr [rbp - 208]   # 32-byte Reload
	xor	ebx, ebx
	and	rdi, rax
	mov	rax, r8
	imul	rax, r12
	vmovaps	ymm0, ymm3
	vmovaps	ymm2, ymm4
	add	rax, rdx
	add	rax, 32
	.p2align	4, 0x90
.LBB0_27:                               # %vector.body372
                                        #   Parent Loop BB0_6 Depth=1
                                        #     Parent Loop BB0_8 Depth=2
                                        # =>    This Inner Loop Header: Depth=3
	vmovups	ymm5, ymmword ptr [rsi + 4*rbx]
	vmovups	ymm6, ymmword ptr [rsi + 4*rbx + 32]
	vfmadd231ps	ymm0, ymm5, ymmword ptr [rax + 4*rbx - 32] # ymm0 = (ymm5 * mem) + ymm0
	vfmadd231ps	ymm2, ymm6, ymmword ptr [rax + 4*rbx] # ymm2 = (ymm6 * mem) + ymm2
	add	rbx, 16
	vfmadd231ps	ymm3, ymm5, ymm5        # ymm3 = (ymm5 * ymm5) + ymm3
	vfmadd231ps	ymm4, ymm6, ymm6        # ymm4 = (ymm6 * ymm6) + ymm4
	cmp	rdi, rbx
	jne	.LBB0_27
# %bb.28:                               # %middle.block364
                                        #   in Loop: Header=BB0_8 Depth=2
	vaddps	ymm3, ymm4, ymm3
	vaddps	ymm0, ymm2, ymm0
	mov	rbx, qword ptr [rbp - 64]       # 8-byte Reload
	cmp	rcx, rdi
	vextractf128	xmm2, ymm3, 1
	vaddps	xmm2, xmm3, xmm2
	vextractf128	xmm3, ymm0, 1
	vaddps	xmm0, xmm0, xmm3
	vpermilpd	xmm3, xmm2, 1           # xmm3 = xmm2[1,0]
	vpermilpd	xmm4, xmm0, 1           # xmm4 = xmm0[1,0]
	vaddps	xmm2, xmm2, xmm3
	vaddps	xmm0, xmm0, xmm4
	vmovshdup	xmm3, xmm2              # xmm3 = xmm2[1,1,3,3]
	vmovshdup	xmm4, xmm0              # xmm4 = xmm0[1,1,3,3]
	vaddss	xmm3, xmm2, xmm3
	vaddss	xmm7, xmm0, xmm4
	je	.LBB0_31
.LBB0_29:                               # %scalar.ph365
                                        #   in Loop: Header=BB0_8 Depth=2
	imul	r8, r12
	add	rdx, r8
	.p2align	4, 0x90
.LBB0_30:                               # %L96
                                        #   Parent Loop BB0_6 Depth=1
                                        #     Parent Loop BB0_8 Depth=2
                                        # =>    This Inner Loop Header: Depth=3
	vmovss	xmm0, dword ptr [rsi + 4*rdi]   # xmm0 = mem[0],zero,zero,zero
	vfmadd231ss	xmm7, xmm0, dword ptr [rdx + 4*rdi] # xmm7 = (xmm0 * mem) + xmm7
	add	rdi, 1
	vfmadd231ss	xmm3, xmm0, xmm0        # xmm3 = (xmm0 * xmm0) + xmm3
	cmp	rcx, rdi
	jne	.LBB0_30
.LBB0_31:                               # %L124
                                        #   in Loop: Header=BB0_8 Depth=2
	cmp	r9, qword ptr [r11 + 8]
	jae	.LBB0_32
# %bb.66:                               # %idxend46
                                        #   in Loop: Header=BB0_8 Depth=2
	vsubss	xmm0, xmm1, xmm1
	mov	rax, qword ptr [r11]
	vucomiss	xmm0, xmm0
	vmovss	xmm0, dword ptr [rax + 4*r14 - 4] # xmm0 = mem[0],zero,zero,zero
	jp	.LBB0_58
# %bb.67:                               # %idxend46
                                        #   in Loop: Header=BB0_8 Depth=2
	mov	rsi, qword ptr [rbx]
	movabs	rax, offset .LCPI0_2
	mov	rdx, qword ptr [rsi + 24]
	mov	rcx, qword ptr [rdx + 8]
	vcvtsi2ss	xmm2, xmm13, rcx
	vmulss	xmm2, xmm2, dword ptr [rax]
	vucomiss	xmm1, xmm2
	jb	.LBB0_58
# %bb.68:                               # %idxend46
                                        #   in Loop: Header=BB0_8 Depth=2
	vsubss	xmm4, xmm3, xmm3
	vucomiss	xmm4, xmm4
	jp	.LBB0_58
# %bb.69:                               # %idxend46
                                        #   in Loop: Header=BB0_8 Depth=2
	vucomiss	xmm3, xmm2
	jb	.LBB0_58
# %bb.35:                               # %L148
                                        #   in Loop: Header=BB0_8 Depth=2
	vucomiss	xmm11, xmm1
	ja	.LBB0_70
# %bb.36:                               # %L152
                                        #   in Loop: Header=BB0_8 Depth=2
	vsqrtss	xmm4, xmm1, xmm1
	vmovss	xmm5, dword ptr [rbx + 8]       # xmm5 = mem[0],zero,zero,zero
	vxorps	xmm2, xmm2, xmm2
	vucomiss	xmm5, xmm4
	jae	.LBB0_59
# %bb.37:                               # %L157
                                        #   in Loop: Header=BB0_8 Depth=2
	vdivss	xmm6, xmm7, xmm1
	movabs	rax, offset .LCPI0_3
	vmulss	xmm2, xmm3, dword ptr [rax]
	vmulss	xmm1, xmm7, xmm6
	vsubss	xmm1, xmm3, xmm1
	vucomiss	xmm2, xmm1
	jbe	.LBB0_50
# %bb.38:                               # %L163
                                        #   in Loop: Header=BB0_8 Depth=2
	mov	rdi, qword ptr [rsi]
	cmp	r9, qword ptr [rdi + 32]
	mov	rax, qword ptr [rdi + 24]
	mov	qword ptr [rbp - 48], rax       # 8-byte Spill
	jae	.LBB0_71
# %bb.39:                               # %L184
                                        #   in Loop: Header=BB0_8 Depth=2
	test	rcx, rcx
	je	.LBB0_40
# %bb.41:                               # %L208.lr.ph
                                        #   in Loop: Header=BB0_8 Depth=2
	mov	rax, qword ptr [rdx]
	mov	rdx, qword ptr [rdi]
	cmp	rcx, 16
	jae	.LBB0_46
# %bb.42:                               #   in Loop: Header=BB0_8 Depth=2
	vxorps	xmm1, xmm1, xmm1
	xor	esi, esi
	jmp	.LBB0_43
.LBB0_40:                               #   in Loop: Header=BB0_8 Depth=2
	vxorps	xmm1, xmm1, xmm1
	mov	qword ptr [rbp - 56], r14       # 8-byte Spill
	jmp	.LBB0_51
.LBB0_46:                               # %vector.ph
                                        #   in Loop: Header=BB0_8 Depth=2
	mov	rsi, rcx
	movabs	rdi, 9223372036854775792
	movabs	rbx, offset .LCPI0_0
	vbroadcastss	ymm2, xmm6
	and	rsi, rdi
	movabs	rdi, offset .LCPI0_1
	vmovaps	ymm3, ymmword ptr [rbx]
	xor	ebx, ebx
	vbroadcastss	ymm1, dword ptr [rdi]
	mov	rdi, qword ptr [rbp - 48]       # 8-byte Reload
	imul	rdi, r12
	add	rdi, rdx
	add	rdi, 32
	.p2align	4, 0x90
.LBB0_47:                               # %vector.body
                                        #   Parent Loop BB0_6 Depth=1
                                        #     Parent Loop BB0_8 Depth=2
                                        # =>    This Inner Loop Header: Depth=3
	vmulps	ymm7, ymm2, ymmword ptr [rdi + 4*rbx - 32]
	vmulps	ymm8, ymm2, ymmword ptr [rdi + 4*rbx]
	vmovups	ymm9, ymmword ptr [rax + 4*rbx]
	vmovups	ymm12, ymmword ptr [rax + 4*rbx + 32]
	add	rbx, 16
	cmp	rsi, rbx
	vsubps	ymm7, ymm9, ymm7
	vsubps	ymm8, ymm12, ymm8
	vfmadd231ps	ymm3, ymm7, ymm7        # ymm3 = (ymm7 * ymm7) + ymm3
	vfmadd231ps	ymm1, ymm8, ymm8        # ymm1 = (ymm8 * ymm8) + ymm1
	jne	.LBB0_47
# %bb.48:                               # %middle.block
                                        #   in Loop: Header=BB0_8 Depth=2
	vaddps	ymm1, ymm1, ymm3
	mov	rbx, qword ptr [rbp - 64]       # 8-byte Reload
	cmp	rcx, rsi
	vextractf128	xmm2, ymm1, 1
	vaddps	xmm1, xmm1, xmm2
	vpermilpd	xmm2, xmm1, 1           # xmm2 = xmm1[1,0]
	vaddps	xmm1, xmm1, xmm2
	vmovshdup	xmm2, xmm1              # xmm2 = xmm1[1,1,3,3]
	vaddss	xmm1, xmm1, xmm2
	jne	.LBB0_43
# %bb.49:                               #   in Loop: Header=BB0_8 Depth=2
	mov	qword ptr [rbp - 56], r14       # 8-byte Spill
	jmp	.LBB0_50
.LBB0_43:                               # %scalar.ph
                                        #   in Loop: Header=BB0_8 Depth=2
	mov	rdi, qword ptr [rbp - 48]       # 8-byte Reload
	imul	rdi, r12
	add	rdx, rdi
	.p2align	4, 0x90
.LBB0_44:                               # %L208
                                        #   Parent Loop BB0_6 Depth=1
                                        #     Parent Loop BB0_8 Depth=2
                                        # =>    This Inner Loop Header: Depth=3
	vmulss	xmm2, xmm6, dword ptr [rdx + 4*rsi]
	vmovss	xmm3, dword ptr [rax + 4*rsi]   # xmm3 = mem[0],zero,zero,zero
	add	rsi, 1
	cmp	rcx, rsi
	vsubss	xmm2, xmm3, xmm2
	vfmadd231ss	xmm1, xmm2, xmm2        # xmm1 = (xmm2 * xmm2) + xmm1
	jne	.LBB0_44
# %bb.45:                               #   in Loop: Header=BB0_8 Depth=2
	mov	qword ptr [rbp - 56], r14       # 8-byte Spill
.LBB0_50:                               # %L245
                                        #   in Loop: Header=BB0_8 Depth=2
	vucomiss	xmm11, xmm1
	ja	.LBB0_72
.LBB0_51:                               # %L252
                                        #   in Loop: Header=BB0_8 Depth=2
	vsubss	xmm2, xmm4, xmm5
	vucomiss	xmm11, xmm2
	ja	.LBB0_73
# %bb.52:                               # %L259
                                        #   in Loop: Header=BB0_8 Depth=2
	vaddss	xmm3, xmm4, xmm5
	vucomiss	xmm11, xmm3
	ja	.LBB0_74
# %bb.53:                               # %L266
                                        #   in Loop: Header=BB0_8 Depth=2
	vsqrtss	xmm2, xmm2, xmm2
	vsqrtss	xmm3, xmm3, xmm3
	vsqrtss	xmm1, xmm1, xmm1
	vmulss	xmm2, xmm2, xmm3
	vdivss	xmm3, xmm5, xmm4
	vaddss	xmm4, xmm6, xmm0
	vdivss	xmm1, xmm1, xmm2
	vmulss	xmm3, xmm3, xmm1
	vxorps	xmm1, xmm1, xmm1
	vsubss	xmm0, xmm4, xmm3
	vmovd	eax, xmm0
	vmovaps	xmm2, xmm0
	test	eax, eax
	jns	.LBB0_55
# %bb.54:                               # %L266
                                        #   in Loop: Header=BB0_8 Depth=2
	vxorps	xmm2, xmm2, xmm2
.LBB0_55:                               # %L266
                                        #   in Loop: Header=BB0_8 Depth=2
	vaddss	xmm3, xmm4, xmm3
	vmovd	eax, xmm3
	test	eax, eax
	jns	.LBB0_57
# %bb.56:                               # %L266
                                        #   in Loop: Header=BB0_8 Depth=2
	vmovaps	xmm1, xmm3
.LBB0_57:                               # %L266
                                        #   in Loop: Header=BB0_8 Depth=2
	vcmpordss	xmm4, xmm0, xmm0
	vcmpordss	xmm5, xmm3, xmm3
	vblendvps	xmm0, xmm0, xmm2, xmm4
	vblendvps	xmm1, xmm3, xmm1, xmm5
	vaddss	xmm2, xmm0, xmm1
	jmp	.LBB0_59
.LBB0_13:                               # %L40
                                        #   in Loop: Header=BB0_8 Depth=2
	test	rcx, rcx
	je	.LBB0_14
# %bb.15:                               # %L54.lr.ph
                                        #   in Loop: Header=BB0_8 Depth=2
	mov	rdx, qword ptr [rsi]
	mov	r8, qword ptr [rsi + 24]
	mov	rsi, qword ptr [rax]
	cmp	rcx, 8
	jae	.LBB0_17
# %bb.16:                               #   in Loop: Header=BB0_8 Depth=2
	vxorps	xmm1, xmm1, xmm1
	xor	edi, edi
	vxorps	xmm7, xmm7, xmm7
	vxorps	xmm3, xmm3, xmm3
	jmp	.LBB0_20
.LBB0_14:                               #   in Loop: Header=BB0_8 Depth=2
	vxorps	xmm3, xmm3, xmm3
	vxorps	xmm7, xmm7, xmm7
	vxorps	xmm1, xmm1, xmm1
	jmp	.LBB0_31
.LBB0_17:                               # %vector.ph390
                                        #   in Loop: Header=BB0_8 Depth=2
	movabs	rax, 9223372036854775792
	movabs	rbx, offset .LCPI0_0
	lea	rdi, [rax + 8]
	mov	rax, r8
	vmovaps	ymm0, ymmword ptr [rbx]
	xor	ebx, ebx
	imul	rax, r12
	and	rdi, rcx
	vmovaps	ymm1, ymm0
	vmovaps	ymm2, ymm0
	add	rax, rdx
.LBB0_18:                               # %vector.body395
                                        #   Parent Loop BB0_6 Depth=1
                                        #     Parent Loop BB0_8 Depth=2
                                        # =>    This Inner Loop Header: Depth=3
	vmovups	ymm3, ymmword ptr [rax + 4*rbx]
	vmovups	ymm4, ymmword ptr [rsi + 4*rbx]
	add	rbx, 8
	cmp	rdi, rbx
	vfmadd231ps	ymm0, ymm3, ymm3        # ymm0 = (ymm3 * ymm3) + ymm0
	vfmadd231ps	ymm1, ymm4, ymm3        # ymm1 = (ymm4 * ymm3) + ymm1
	vfmadd231ps	ymm2, ymm4, ymm4        # ymm2 = (ymm4 * ymm4) + ymm2
	jne	.LBB0_18
# %bb.19:                               # %middle.block387
                                        #   in Loop: Header=BB0_8 Depth=2
	vextractf128	xmm3, ymm2, 1
	mov	rbx, qword ptr [rbp - 64]       # 8-byte Reload
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
	vaddss	xmm3, xmm2, xmm3
	vmovshdup	xmm2, xmm1              # xmm2 = xmm1[1,1,3,3]
	vmovshdup	xmm4, xmm0              # xmm4 = xmm0[1,1,3,3]
	vaddss	xmm7, xmm1, xmm2
	vaddss	xmm1, xmm0, xmm4
	je	.LBB0_31
.LBB0_20:                               # %scalar.ph388
                                        #   in Loop: Header=BB0_8 Depth=2
	imul	r8, r12
	add	rdx, r8
.LBB0_21:                               # %L54
                                        #   Parent Loop BB0_6 Depth=1
                                        #     Parent Loop BB0_8 Depth=2
                                        # =>    This Inner Loop Header: Depth=3
	vmovss	xmm0, dword ptr [rdx + 4*rdi]   # xmm0 = mem[0],zero,zero,zero
	vmovss	xmm2, dword ptr [rsi + 4*rdi]   # xmm2 = mem[0],zero,zero,zero
	add	rdi, 1
	cmp	rcx, rdi
	vfmadd231ss	xmm1, xmm0, xmm0        # xmm1 = (xmm0 * xmm0) + xmm1
	vfmadd231ss	xmm7, xmm2, xmm0        # xmm7 = (xmm2 * xmm0) + xmm7
	vfmadd231ss	xmm3, xmm2, xmm2        # xmm3 = (xmm2 * xmm2) + xmm3
	jne	.LBB0_21
	jmp	.LBB0_31
	.p2align	4, 0x90
.LBB0_60:                               # %L307
                                        #   in Loop: Header=BB0_6 Depth=1
	mov	rax, qword ptr [rbp - 136]      # 8-byte Reload
	cmp	rax, qword ptr [rbp - 128]      # 8-byte Folded Reload
	je	.LBB0_61
# %bb.5:                                # %L17thread-pre-split
                                        #   in Loop: Header=BB0_6 Depth=1
	mov	r10, qword ptr [r11 + 8]
	add	rax, 1
	jmp	.LBB0_6
.LBB0_61:
	mov	rcx, qword ptr [rbp - 120]      # 8-byte Reload
	mov	rdx, qword ptr [rbp - 56]       # 8-byte Reload
	jmp	.LBB0_62
.LBB0_1:
	vxorps	xmm10, xmm10, xmm10
	jmp	.LBB0_63
.LBB0_3:
                                        # implicit-def: $rax
	vxorps	xmm10, xmm10, xmm10
                                        # implicit-def: $rdx
                                        # kill: killed $rax
.LBB0_62:                               # %L318.loopexit
	mov	rax, qword ptr [rbp - 48]       # 8-byte Reload
	mov	qword ptr [rbp - 112], rax
	mov	qword ptr [rbp - 104], rdx
.LBB0_63:                               # %L318
	mov	rax, qword ptr [rbp - 88]
	vmovaps	xmm0, xmm10
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
.LBB0_9:                                # %oob
	mov	rsi, rsp
	mov	eax, 16
	sub	rsi, rax
	cmp	rsi, rsp
	jge	.LBB0_64
.LBB0_11:                               # %oob
                                        # =>This Inner Loop Header: Depth=1
	xor	qword ptr [rsp], 0
	sub	rsp, 4096
	cmp	rsi, rsp
	jl	.LBB0_11
.LBB0_64:                               # %oob
	mov	rsp, rsi
	movabs	rax, offset ijl_bounds_error_ints
	mov	edx, 1
	mov	qword ptr [rsi], r14
	vzeroupper
	call	rax
.LBB0_32:                               # %oob44
	mov	rsi, rsp
	mov	eax, 16
	sub	rsi, rax
	cmp	rsi, rsp
	jge	.LBB0_65
.LBB0_34:                               # %oob44
                                        # =>This Inner Loop Header: Depth=1
	xor	qword ptr [rsp], 0
	sub	rsp, 4096
	cmp	rsi, rsp
	jl	.LBB0_34
.LBB0_65:                               # %oob44
	mov	rsp, rsi
	movabs	rax, offset ijl_bounds_error_ints
	mov	edx, 1
	mov	rdi, r11
	mov	qword ptr [rsi], r14
	vzeroupper
	call	rax
.LBB0_70:                               # %L150
	movabs	rax, offset j_throw_complex_domainerror_1892
	movabs	rdi, 136709640595984
	vmovaps	xmm0, xmm1
	vzeroupper
	call	rax
.LBB0_73:                               # %L257
	movabs	rax, offset j_throw_complex_domainerror_1892
	movabs	rdi, 136709640595984
	vmovaps	xmm0, xmm2
	vzeroupper
	call	rax
.LBB0_74:                               # %L264
	movabs	rax, offset j_throw_complex_domainerror_1892
	movabs	rdi, 136709640595984
	vmovaps	xmm0, xmm3
	vzeroupper
	call	rax
.LBB0_72:                               # %L250
	movabs	rax, offset j_throw_complex_domainerror_1892
	movabs	rdi, 136709640595984
	vmovaps	xmm0, xmm1
	vzeroupper
	call	rax
.LBB0_71:                               # %L181
	mov	rax, qword ptr [rbp - 48]       # 8-byte Reload
	lea	rsi, [rbp - 112]
	mov	qword ptr [rbp - 80], rdi
	mov	qword ptr [rbp - 112], rax
	movabs	rax, offset j_throw_boundserror_1894
	mov	qword ptr [rbp - 104], r14
	vzeroupper
	call	rax
.Lfunc_end0:
	.size	julia_pass_1889, .Lfunc_end0-julia_pass_1889
                                        # -- End function
	.section	".note.GNU-stack","",@progbits
