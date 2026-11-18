	.text
	.file	"pass"
	.section	.rodata.cst32,"aM",@progbits,32
	.p2align	5                               # -- Begin function julia_pass_1644
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
	.text
	.globl	julia_pass_1644
	.p2align	4, 0x90
	.type	julia_pass_1644,@function
julia_pass_1644:                        # @julia_pass_1644
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
	vmovaps	xmmword ptr [rbp - 96], xmm0
	mov	qword ptr [rbp - 80], 0
	#APP
	mov	rax, qword ptr fs:[0]
	#NO_APP
	mov	rcx, qword ptr [rax - 8]
	mov	qword ptr [rbp - 96], 4
	mov	rax, qword ptr [rcx]
	mov	qword ptr [rbp - 88], rax
	lea	rax, [rbp - 96]
	mov	qword ptr [rcx], rax
	xor	eax, eax
	vxorps	xmm1, xmm1, xmm1
	test	rdx, rdx
	cmovg	rax, rdx
	mov	qword ptr [rbp - 112], rax      # 8-byte Spill
	jle	.LBB0_75
# %bb.1:                                # %L17.preheader
	mov	r10, rsi
	mov	r15, qword ptr [rsi + 8]
	test	r15, r15
	je	.LBB0_75
# %bb.2:                                # %L17.preheader371
	mov	r12, rdi
	mov	qword ptr [rbp - 104], rcx      # 8-byte Spill
	mov	rbx, qword ptr [rdi]
	vxorps	xmm13, xmm13, xmm13
	mov	eax, 1
	movabs	rcx, offset .LCPI0_1
	vbroadcastss	ymm0, dword ptr [rcx]
	vmovups	ymmword ptr [rbp - 192], ymm0   # 32-byte Spill
	movabs	rcx, offset .LCPI0_0
	vmovaps	ymm0, ymmword ptr [rcx]
	vmovups	ymmword ptr [rbp - 160], ymm0   # 32-byte Spill
	vxorps	xmm1, xmm1, xmm1
	mov	qword ptr [rbp - 64], rdi       # 8-byte Spill
	mov	qword ptr [rbp - 56], r10       # 8-byte Spill
	mov	qword ptr [rbp - 48], rbx       # 8-byte Spill
	.p2align	4, 0x90
.LBB0_4:                                # %L17
                                        # =>This Loop Header: Depth=1
                                        #     Child Loop BB0_6 Depth 2
                                        #       Child Loop BB0_18 Depth 3
                                        #       Child Loop BB0_21 Depth 3
                                        #       Child Loop BB0_24 Depth 3
                                        #       Child Loop BB0_32 Depth 3
                                        #       Child Loop BB0_37 Depth 3
                                        #       Child Loop BB0_52 Depth 3
                                        #       Child Loop BB0_57 Depth 3
	mov	qword ptr [rbp - 120], rax      # 8-byte Spill
	test	r15, r15
	je	.LBB0_73
# %bb.5:                                # %L31.preheader
                                        #   in Loop: Header=BB0_4 Depth=1
	mov	r14d, 1
	xor	r13d, r13d
	jmp	.LBB0_6
	.p2align	4, 0x90
.LBB0_71:                               # %L323
                                        #   in Loop: Header=BB0_6 Depth=2
	mov	qword ptr [rbp - 80], rbx
	mov	rdi, r12
	vmovaps	xmm0, xmm8
	mov	rsi, r14
	movabs	rax, offset j__sqrt_offrange_step_1650
	vzeroupper
	call	rax
	mov	rbx, qword ptr [rbp - 48]       # 8-byte Reload
	mov	r10, qword ptr [rbp - 56]       # 8-byte Reload
	vxorps	xmm13, xmm13, xmm13
	vmovaps	xmm4, xmm0
.LBB0_72:                               # %L325
                                        #   in Loop: Header=BB0_6 Depth=2
	vmovss	xmm1, dword ptr [rbp - 68]      # 4-byte Reload
                                        # xmm1 = mem[0],zero,zero,zero
	vaddss	xmm1, xmm1, xmm4
	lea	rax, [r14 + 1]
	add	r13, 4
	cmp	r14, r15
	mov	r14, rax
	je	.LBB0_73
.LBB0_6:                                # %L31
                                        #   Parent Loop BB0_4 Depth=1
                                        # =>  This Loop Header: Depth=2
                                        #       Child Loop BB0_18 Depth 3
                                        #       Child Loop BB0_21 Depth 3
                                        #       Child Loop BB0_24 Depth 3
                                        #       Child Loop BB0_32 Depth 3
                                        #       Child Loop BB0_37 Depth 3
                                        #       Child Loop BB0_52 Depth 3
                                        #       Child Loop BB0_57 Depth 3
	mov	rdi, qword ptr [rbx + 32]
	lea	r9, [r14 - 1]
	cmp	r9, qword ptr [rdi + 8]
	jae	.LBB0_7
# %bb.10:                               # %idxend
                                        #   in Loop: Header=BB0_6 Depth=2
	mov	rsi, qword ptr [rbx]
	mov	rax, qword ptr [rbx + 24]
	mov	rcx, qword ptr [rdi]
	vmovss	xmm0, dword ptr [rcx + 4*r14 - 4] # xmm0 = mem[0],zero,zero,zero
	vucomiss	xmm0, xmm0
	mov	r11, qword ptr [rax + 8]
	vmovss	dword ptr [rbp - 68], xmm1      # 4-byte Spill
	jp	.LBB0_11
# %bb.25:                               # %L83
                                        #   in Loop: Header=BB0_6 Depth=2
	test	r11, r11
	je	.LBB0_26
# %bb.27:                               # %L96.lr.ph
                                        #   in Loop: Header=BB0_6 Depth=2
	mov	rdx, qword ptr [rsi]
	mov	r8, qword ptr [rsi + 24]
	mov	rsi, qword ptr [rax]
	cmp	r11, 16
	jae	.LBB0_29
# %bb.28:                               #   in Loop: Header=BB0_6 Depth=2
	vxorps	xmm3, xmm3, xmm3
	xor	edi, edi
	vxorps	xmm7, xmm7, xmm7
	jmp	.LBB0_36
	.p2align	4, 0x90
.LBB0_26:                               #   in Loop: Header=BB0_6 Depth=2
	vxorps	xmm7, xmm7, xmm7
	vxorps	xmm3, xmm3, xmm3
	jmp	.LBB0_38
	.p2align	4, 0x90
.LBB0_29:                               # %vector.ph271
                                        #   in Loop: Header=BB0_6 Depth=2
	mov	rdi, r11
	movabs	rax, 9223372036854775792
	and	rdi, rax
	lea	rax, [rdi - 16]
	mov	r10, rax
	shr	r10, 4
	inc	r10
	test	rax, rax
	je	.LBB0_30
# %bb.31:                               # %vector.ph271.new
                                        #   in Loop: Header=BB0_6 Depth=2
	mov	rbx, r10
	movabs	rax, 2305843009213693950
	and	rbx, rax
	mov	rax, r8
	imul	rax, r13
	lea	rcx, [rdx + rax]
	add	rcx, 96
	movabs	rax, offset .LCPI0_1
	vbroadcastss	ymm2, dword ptr [rax]
	movabs	rax, offset .LCPI0_0
	vmovaps	ymm1, ymmword ptr [rax]
	xor	eax, eax
	vmovaps	ymm3, ymm1
	vmovaps	ymm4, ymm2
	.p2align	4, 0x90
.LBB0_32:                               # %vector.body276
                                        #   Parent Loop BB0_4 Depth=1
                                        #     Parent Loop BB0_6 Depth=2
                                        # =>    This Inner Loop Header: Depth=3
	vmovups	ymm5, ymmword ptr [rsi + 4*rax]
	vmovups	ymm6, ymmword ptr [rsi + 4*rax + 32]
	vmovups	ymm7, ymmword ptr [rsi + 4*rax + 64]
	vmovups	ymm8, ymmword ptr [rsi + 4*rax + 96]
	vfmadd231ps	ymm1, ymm5, ymmword ptr [rcx + 4*rax - 96] # ymm1 = (ymm5 * mem) + ymm1
	vfmadd231ps	ymm2, ymm6, ymmword ptr [rcx + 4*rax - 64] # ymm2 = (ymm6 * mem) + ymm2
	vfmadd231ps	ymm3, ymm5, ymm5        # ymm3 = (ymm5 * ymm5) + ymm3
	vfmadd231ps	ymm4, ymm6, ymm6        # ymm4 = (ymm6 * ymm6) + ymm4
	vfmadd231ps	ymm1, ymm7, ymmword ptr [rcx + 4*rax - 32] # ymm1 = (ymm7 * mem) + ymm1
	vfmadd231ps	ymm2, ymm8, ymmword ptr [rcx + 4*rax] # ymm2 = (ymm8 * mem) + ymm2
	vfmadd231ps	ymm3, ymm7, ymm7        # ymm3 = (ymm7 * ymm7) + ymm3
	vfmadd231ps	ymm4, ymm8, ymm8        # ymm4 = (ymm8 * ymm8) + ymm4
	add	rax, 32
	add	rbx, -2
	jne	.LBB0_32
# %bb.33:                               # %middle.block268.unr-lcssa
                                        #   in Loop: Header=BB0_6 Depth=2
	test	r10b, 1
	je	.LBB0_35
.LBB0_34:                               # %vector.body276.epil.preheader
                                        #   in Loop: Header=BB0_6 Depth=2
	mov	rcx, r8
	imul	rcx, r9
	add	rcx, rax
	vmovups	ymm5, ymmword ptr [rsi + 4*rax]
	vmovups	ymm6, ymmword ptr [rsi + 4*rax + 32]
	vfmadd231ps	ymm1, ymm5, ymmword ptr [rdx + 4*rcx] # ymm1 = (ymm5 * mem) + ymm1
	vfmadd231ps	ymm2, ymm6, ymmword ptr [rdx + 4*rcx + 32] # ymm2 = (ymm6 * mem) + ymm2
	vfmadd231ps	ymm3, ymm5, ymm5        # ymm3 = (ymm5 * ymm5) + ymm3
	vfmadd231ps	ymm4, ymm6, ymm6        # ymm4 = (ymm6 * ymm6) + ymm4
.LBB0_35:                               # %middle.block268
                                        #   in Loop: Header=BB0_6 Depth=2
	vaddps	ymm1, ymm2, ymm1
	vaddps	ymm2, ymm4, ymm3
	vextractf128	xmm3, ymm2, 1
	vaddps	xmm2, xmm2, xmm3
	vpermilpd	xmm3, xmm2, 1           # xmm3 = xmm2[1,0]
	vaddps	xmm2, xmm2, xmm3
	vmovshdup	xmm3, xmm2              # xmm3 = xmm2[1,1,3,3]
	vaddss	xmm7, xmm2, xmm3
	vextractf128	xmm2, ymm1, 1
	vaddps	xmm1, xmm1, xmm2
	vpermilpd	xmm2, xmm1, 1           # xmm2 = xmm1[1,0]
	vaddps	xmm1, xmm1, xmm2
	vmovshdup	xmm2, xmm1              # xmm2 = xmm1[1,1,3,3]
	vaddss	xmm3, xmm1, xmm2
	cmp	r11, rdi
	mov	r12, qword ptr [rbp - 64]       # 8-byte Reload
	mov	r10, qword ptr [rbp - 56]       # 8-byte Reload
	mov	rbx, qword ptr [rbp - 48]       # 8-byte Reload
	je	.LBB0_38
.LBB0_36:                               # %scalar.ph269
                                        #   in Loop: Header=BB0_6 Depth=2
	imul	r8, r13
	add	rdx, r8
	.p2align	4, 0x90
.LBB0_37:                               # %L96
                                        #   Parent Loop BB0_4 Depth=1
                                        #     Parent Loop BB0_6 Depth=2
                                        # =>    This Inner Loop Header: Depth=3
	vmovss	xmm1, dword ptr [rsi + 4*rdi]   # xmm1 = mem[0],zero,zero,zero
	vfmadd231ss	xmm3, xmm1, dword ptr [rdx + 4*rdi] # xmm3 = (xmm1 * mem) + xmm3
	vfmadd231ss	xmm7, xmm1, xmm1        # xmm7 = (xmm1 * xmm1) + xmm7
	inc	rdi
	cmp	r11, rdi
	jne	.LBB0_37
.LBB0_38:                               # %L124
                                        #   in Loop: Header=BB0_6 Depth=2
	cmp	r9, qword ptr [r10 + 8]
	jae	.LBB0_39
# %bb.78:                               # %idxend46
                                        #   in Loop: Header=BB0_6 Depth=2
	mov	rax, qword ptr [r10]
	vmovss	xmm8, dword ptr [rax + 4*r14 - 4] # xmm8 = mem[0],zero,zero,zero
	vsubss	xmm1, xmm0, xmm0
	vucomiss	xmm1, xmm1
	jp	.LBB0_71
# %bb.79:                               # %idxend46
                                        #   in Loop: Header=BB0_6 Depth=2
	mov	rax, qword ptr [r12]
	mov	rdx, qword ptr [rax + 24]
	mov	rcx, qword ptr [rdx + 8]
	vcvtsi2ss	xmm1, xmm14, rcx
	movabs	rsi, offset .LCPI0_2
	vmulss	xmm5, xmm1, dword ptr [rsi]
	vucomiss	xmm0, xmm5
	jb	.LBB0_71
# %bb.80:                               # %idxend46
                                        #   in Loop: Header=BB0_6 Depth=2
	vsubss	xmm1, xmm7, xmm7
	vucomiss	xmm1, xmm1
	jp	.LBB0_71
# %bb.81:                               # %idxend46
                                        #   in Loop: Header=BB0_6 Depth=2
	vucomiss	xmm7, xmm5
	jb	.LBB0_71
# %bb.42:                               # %L144
                                        #   in Loop: Header=BB0_6 Depth=2
	vucomiss	xmm13, xmm0
	ja	.LBB0_82
# %bb.43:                               # %L150
                                        #   in Loop: Header=BB0_6 Depth=2
	vmovss	xmm2, dword ptr [r12 + 8]       # xmm2 = mem[0],zero,zero,zero
	vsqrtss	xmm1, xmm0, xmm0
	vxorps	xmm4, xmm4, xmm4
	vucomiss	xmm2, xmm1
	jae	.LBB0_72
# %bb.44:                               # %L155
                                        #   in Loop: Header=BB0_6 Depth=2
	vdivss	xmm6, xmm3, xmm0
	vmulss	xmm0, xmm3, xmm6
	vsubss	xmm0, xmm7, xmm0
	movabs	rsi, offset .LCPI0_3
	vmulss	xmm3, xmm7, dword ptr [rsi]
	vucomiss	xmm3, xmm0
	jbe	.LBB0_61
# %bb.45:                               # %L162
                                        #   in Loop: Header=BB0_6 Depth=2
	test	rcx, rcx
	je	.LBB0_46
# %bb.47:                               # %L176.lr.ph
                                        #   in Loop: Header=BB0_6 Depth=2
	mov	rsi, qword ptr [rax]
	mov	rax, qword ptr [rdx]
	mov	r11, qword ptr [rsi]
	mov	r8, qword ptr [rsi + 24]
	cmp	rcx, 16
	jae	.LBB0_49
# %bb.48:                               #   in Loop: Header=BB0_6 Depth=2
	vxorps	xmm0, xmm0, xmm0
	xor	esi, esi
	jmp	.LBB0_56
.LBB0_30:                               #   in Loop: Header=BB0_6 Depth=2
	xor	eax, eax
	vmovups	ymm3, ymmword ptr [rbp - 160]   # 32-byte Reload
	vmovaps	ymm1, ymm3
	vmovups	ymm4, ymmword ptr [rbp - 192]   # 32-byte Reload
	vmovaps	ymm2, ymm4
	test	r10b, 1
	je	.LBB0_35
	jmp	.LBB0_34
.LBB0_46:                               #   in Loop: Header=BB0_6 Depth=2
	vxorps	xmm0, xmm0, xmm0
	jmp	.LBB0_58
.LBB0_49:                               # %vector.ph
                                        #   in Loop: Header=BB0_6 Depth=2
	mov	rsi, rcx
	movabs	rdx, 9223372036854775792
	and	rsi, rdx
	vbroadcastss	ymm0, xmm6
	lea	rdx, [rsi - 16]
	mov	r10, rdx
	shr	r10, 4
	inc	r10
	test	rdx, rdx
	je	.LBB0_50
# %bb.51:                               # %vector.ph.new
                                        #   in Loop: Header=BB0_6 Depth=2
	mov	rbx, r10
	movabs	rdx, 2305843009213693950
	and	rbx, rdx
	mov	rdx, r8
	imul	rdx, r13
	add	rdx, r11
	add	rdx, 96
	movabs	rdi, offset .LCPI0_1
	vbroadcastss	ymm3, dword ptr [rdi]
	movabs	rdi, offset .LCPI0_0
	vmovaps	ymm4, ymmword ptr [rdi]
	xor	edi, edi
	.p2align	4, 0x90
.LBB0_52:                               # %vector.body
                                        #   Parent Loop BB0_4 Depth=1
                                        #     Parent Loop BB0_6 Depth=2
                                        # =>    This Inner Loop Header: Depth=3
	vmulps	ymm7, ymm0, ymmword ptr [rdx + 4*rdi - 96]
	vmulps	ymm9, ymm0, ymmword ptr [rdx + 4*rdi - 64]
	vmovups	ymm10, ymmword ptr [rax + 4*rdi]
	vsubps	ymm7, ymm10, ymm7
	vmovups	ymm10, ymmword ptr [rax + 4*rdi + 32]
	vsubps	ymm9, ymm10, ymm9
	vmovups	ymm10, ymmword ptr [rax + 4*rdi + 64]
	vmovups	ymm11, ymmword ptr [rax + 4*rdi + 96]
	vfmadd213ps	ymm7, ymm7, ymm4        # ymm7 = (ymm7 * ymm7) + ymm4
	vfmadd213ps	ymm9, ymm9, ymm3        # ymm9 = (ymm9 * ymm9) + ymm3
	vmulps	ymm3, ymm0, ymmword ptr [rdx + 4*rdi - 32]
	vmulps	ymm12, ymm0, ymmword ptr [rdx + 4*rdi]
	vsubps	ymm4, ymm10, ymm3
	vsubps	ymm3, ymm11, ymm12
	vfmadd213ps	ymm4, ymm4, ymm7        # ymm4 = (ymm4 * ymm4) + ymm7
	vfmadd213ps	ymm3, ymm3, ymm9        # ymm3 = (ymm3 * ymm3) + ymm9
	add	rdi, 32
	add	rbx, -2
	jne	.LBB0_52
# %bb.53:                               # %middle.block.unr-lcssa
                                        #   in Loop: Header=BB0_6 Depth=2
	test	r10b, 1
	je	.LBB0_55
.LBB0_54:                               # %vector.body.epil.preheader
                                        #   in Loop: Header=BB0_6 Depth=2
	imul	r9, r8
	vmovups	ymm7, ymmword ptr [rax + 4*rdi]
	vmovups	ymm9, ymmword ptr [rax + 4*rdi + 32]
	add	r9, rdi
	vmulps	ymm10, ymm0, ymmword ptr [r11 + 4*r9]
	vsubps	ymm7, ymm7, ymm10
	vmulps	ymm0, ymm0, ymmword ptr [r11 + 4*r9 + 32]
	vsubps	ymm0, ymm9, ymm0
	vfmadd231ps	ymm4, ymm7, ymm7        # ymm4 = (ymm7 * ymm7) + ymm4
	vfmadd231ps	ymm3, ymm0, ymm0        # ymm3 = (ymm0 * ymm0) + ymm3
.LBB0_55:                               # %middle.block
                                        #   in Loop: Header=BB0_6 Depth=2
	vaddps	ymm0, ymm3, ymm4
	vextractf128	xmm3, ymm0, 1
	vaddps	xmm0, xmm0, xmm3
	vpermilpd	xmm3, xmm0, 1           # xmm3 = xmm0[1,0]
	vaddps	xmm0, xmm0, xmm3
	vmovshdup	xmm3, xmm0              # xmm3 = xmm0[1,1,3,3]
	vaddss	xmm0, xmm0, xmm3
	cmp	rcx, rsi
	mov	r12, qword ptr [rbp - 64]       # 8-byte Reload
	mov	r10, qword ptr [rbp - 56]       # 8-byte Reload
	mov	rbx, qword ptr [rbp - 48]       # 8-byte Reload
	je	.LBB0_58
.LBB0_56:                               # %scalar.ph
                                        #   in Loop: Header=BB0_6 Depth=2
	imul	r8, r13
	add	r11, r8
	.p2align	4, 0x90
.LBB0_57:                               # %L176
                                        #   Parent Loop BB0_4 Depth=1
                                        #     Parent Loop BB0_6 Depth=2
                                        # =>    This Inner Loop Header: Depth=3
	vmovss	xmm3, dword ptr [rax + 4*rsi]   # xmm3 = mem[0],zero,zero,zero
	vmulss	xmm4, xmm6, dword ptr [r11 + 4*rsi]
	vsubss	xmm3, xmm3, xmm4
	vfmadd231ss	xmm0, xmm3, xmm3        # xmm0 = (xmm3 * xmm3) + xmm0
	inc	rsi
	cmp	rcx, rsi
	jne	.LBB0_57
.LBB0_58:                               # %L199
                                        #   in Loop: Header=BB0_6 Depth=2
	vucomiss	xmm0, xmm5
	jb	.LBB0_60
# %bb.59:                               # %L199
                                        #   in Loop: Header=BB0_6 Depth=2
	vsubss	xmm3, xmm0, xmm0
	vucomiss	xmm3, xmm3
	jp	.LBB0_60
.LBB0_61:                               # %L210
                                        #   in Loop: Header=BB0_6 Depth=2
	vucomiss	xmm13, xmm0
	ja	.LBB0_83
# %bb.62:                               # %L215
                                        #   in Loop: Header=BB0_6 Depth=2
	vsubss	xmm4, xmm1, xmm2
	vucomiss	xmm13, xmm4
	movabs	rax, offset .LCPI0_4
	ja	.LBB0_84
# %bb.63:                               # %L222
                                        #   in Loop: Header=BB0_6 Depth=2
	vaddss	xmm5, xmm1, xmm2
	vucomiss	xmm13, xmm5
	ja	.LBB0_85
# %bb.64:                               # %L229
                                        #   in Loop: Header=BB0_6 Depth=2
	vaddss	xmm6, xmm8, xmm6
	vsqrtss	xmm0, xmm0, xmm0
	vsqrtss	xmm3, xmm4, xmm4
	vsqrtss	xmm4, xmm5, xmm5
	vmulss	xmm3, xmm3, xmm4
	vmulss	xmm3, xmm1, xmm3
	vucomiss	xmm3, dword ptr [rax]
	jb	.LBB0_70
# %bb.65:                               # %L229
                                        #   in Loop: Header=BB0_6 Depth=2
	vdivss	xmm3, xmm0, xmm3
	vucomiss	xmm3, dword ptr [rax]
	jb	.LBB0_70
# %bb.66:                               # %L229
                                        #   in Loop: Header=BB0_6 Depth=2
	movabs	rcx, offset .LCPI0_5
	vmovss	xmm4, dword ptr [rcx]           # xmm4 = mem[0],zero,zero,zero
	vucomiss	xmm4, xmm3
	jb	.LBB0_70
# %bb.67:                               # %L229
                                        #   in Loop: Header=BB0_6 Depth=2
	vmulss	xmm3, xmm2, xmm3
	vucomiss	xmm3, dword ptr [rax]
	jb	.LBB0_70
# %bb.68:                               # %L229
                                        #   in Loop: Header=BB0_6 Depth=2
	vucomiss	xmm4, xmm3
	jb	.LBB0_70
# %bb.69:                               # %L263
                                        #   in Loop: Header=BB0_6 Depth=2
	movabs	rax, offset .LCPI0_1
	vbroadcastss	xmm0, dword ptr [rax]
	vxorps	xmm0, xmm3, xmm0
	vmaxss	xmm0, xmm6, xmm0
	vminss	xmm0, xmm0, xmm3
	vsubss	xmm0, xmm6, xmm0
	vaddss	xmm4, xmm13, xmm0
	jmp	.LBB0_72
.LBB0_70:                               # %L320
                                        #   in Loop: Header=BB0_6 Depth=2
	vcvtss2sd	xmm3, xmm0, xmm0
	mov	qword ptr [rbp - 80], rbx
	vmovaps	xmm0, xmm6
	xor	edi, edi
	movabs	rax, offset j__sqrt_band_step_1649
	vzeroupper
	call	rax
	mov	rbx, qword ptr [rbp - 48]       # 8-byte Reload
	mov	r10, qword ptr [rbp - 56]       # 8-byte Reload
	vxorps	xmm13, xmm13, xmm13
	vmovaps	xmm4, xmm0
	jmp	.LBB0_72
.LBB0_60:                               # %L208
                                        #   in Loop: Header=BB0_6 Depth=2
	mov	qword ptr [rbp - 80], rbx
	mov	rdi, r12
	vmovaps	xmm0, xmm8
	mov	rsi, r14
	movabs	rax, offset j__sqrt_offrange_step_1650
	vzeroupper
	call	rax
	mov	rbx, qword ptr [rbp - 48]       # 8-byte Reload
	mov	r10, qword ptr [rbp - 56]       # 8-byte Reload
	vxorps	xmm13, xmm13, xmm13
	vmovaps	xmm4, xmm0
	jmp	.LBB0_72
.LBB0_50:                               #   in Loop: Header=BB0_6 Depth=2
	movabs	rdx, offset .LCPI0_1
	vbroadcastss	ymm3, dword ptr [rdx]
	movabs	rdx, offset .LCPI0_0
	vmovaps	ymm4, ymmword ptr [rdx]
	xor	edi, edi
	test	r10b, 1
	je	.LBB0_55
	jmp	.LBB0_54
.LBB0_11:                               # %L40
                                        #   in Loop: Header=BB0_6 Depth=2
	test	r11, r11
	je	.LBB0_12
# %bb.13:                               # %L54.lr.ph
                                        #   in Loop: Header=BB0_6 Depth=2
	mov	rcx, qword ptr [rsi]
	mov	r8, qword ptr [rsi + 24]
	mov	rsi, qword ptr [rax]
	cmp	r11, 8
	jae	.LBB0_15
# %bb.14:                               #   in Loop: Header=BB0_6 Depth=2
	vxorps	xmm0, xmm0, xmm0
	xor	edi, edi
	vxorps	xmm3, xmm3, xmm3
	vxorps	xmm7, xmm7, xmm7
	jmp	.LBB0_23
.LBB0_12:                               #   in Loop: Header=BB0_6 Depth=2
	vxorps	xmm7, xmm7, xmm7
	vxorps	xmm3, xmm3, xmm3
	vxorps	xmm0, xmm0, xmm0
	jmp	.LBB0_38
.LBB0_15:                               # %vector.ph294
                                        #   in Loop: Header=BB0_6 Depth=2
	movabs	rax, 9223372036854775792
	lea	rdi, [rax + 8]
	and	rdi, r11
	lea	rdx, [rdi - 8]
	mov	rax, rdx
	shr	rax, 3
	inc	rax
	mov	r10d, eax
	and	r10d, 3
	cmp	rdx, 24
	jae	.LBB0_17
# %bb.16:                               #   in Loop: Header=BB0_6 Depth=2
	movabs	rax, offset .LCPI0_0
	vmovaps	ymm0, ymmword ptr [rax]
	xor	ebx, ebx
	vmovaps	ymm1, ymm0
	vmovaps	ymm2, ymm0
	jmp	.LBB0_19
.LBB0_17:                               # %vector.ph294.new
                                        #   in Loop: Header=BB0_6 Depth=2
	and	rax, -4
	mov	rdx, r8
	imul	rdx, r13
	add	rdx, rcx
	add	rdx, 96
	movabs	rbx, offset .LCPI0_0
	vmovaps	ymm0, ymmword ptr [rbx]
	xor	ebx, ebx
	vmovaps	ymm1, ymm0
	vmovaps	ymm2, ymm0
.LBB0_18:                               # %vector.body299
                                        #   Parent Loop BB0_4 Depth=1
                                        #     Parent Loop BB0_6 Depth=2
                                        # =>    This Inner Loop Header: Depth=3
	vmovups	ymm3, ymmword ptr [rdx + 4*rbx - 96]
	vmovups	ymm4, ymmword ptr [rdx + 4*rbx - 64]
	vmovups	ymm5, ymmword ptr [rdx + 4*rbx - 32]
	vmovups	ymm6, ymmword ptr [rdx + 4*rbx]
	vfmadd231ps	ymm0, ymm3, ymm3        # ymm0 = (ymm3 * ymm3) + ymm0
	vmovups	ymm7, ymmword ptr [rsi + 4*rbx]
	vmovups	ymm8, ymmword ptr [rsi + 4*rbx + 32]
	vmovups	ymm9, ymmword ptr [rsi + 4*rbx + 64]
	vmovups	ymm10, ymmword ptr [rsi + 4*rbx + 96]
	vfmadd231ps	ymm1, ymm7, ymm3        # ymm1 = (ymm7 * ymm3) + ymm1
	vfmadd231ps	ymm2, ymm7, ymm7        # ymm2 = (ymm7 * ymm7) + ymm2
	vfmadd231ps	ymm0, ymm4, ymm4        # ymm0 = (ymm4 * ymm4) + ymm0
	vfmadd231ps	ymm1, ymm8, ymm4        # ymm1 = (ymm8 * ymm4) + ymm1
	vfmadd231ps	ymm2, ymm8, ymm8        # ymm2 = (ymm8 * ymm8) + ymm2
	vfmadd231ps	ymm0, ymm5, ymm5        # ymm0 = (ymm5 * ymm5) + ymm0
	vfmadd231ps	ymm1, ymm9, ymm5        # ymm1 = (ymm9 * ymm5) + ymm1
	vfmadd231ps	ymm2, ymm9, ymm9        # ymm2 = (ymm9 * ymm9) + ymm2
	vfmadd231ps	ymm0, ymm6, ymm6        # ymm0 = (ymm6 * ymm6) + ymm0
	vfmadd231ps	ymm1, ymm10, ymm6       # ymm1 = (ymm10 * ymm6) + ymm1
	vfmadd231ps	ymm2, ymm10, ymm10      # ymm2 = (ymm10 * ymm10) + ymm2
	add	rbx, 32
	add	rax, -4
	jne	.LBB0_18
.LBB0_19:                               # %middle.block291.unr-lcssa
                                        #   in Loop: Header=BB0_6 Depth=2
	test	r10, r10
	je	.LBB0_22
# %bb.20:                               # %vector.body299.epil.preheader
                                        #   in Loop: Header=BB0_6 Depth=2
	lea	rax, [rsi + 4*rbx]
	lea	rbx, [rcx + 4*rbx]
	mov	rdx, r8
	imul	rdx, r13
	add	rdx, rbx
	shl	r10, 5
	xor	ebx, ebx
.LBB0_21:                               # %vector.body299.epil
                                        #   Parent Loop BB0_4 Depth=1
                                        #     Parent Loop BB0_6 Depth=2
                                        # =>    This Inner Loop Header: Depth=3
	vmovups	ymm3, ymmword ptr [rdx + rbx]
	vmovups	ymm4, ymmword ptr [rax + rbx]
	vfmadd231ps	ymm0, ymm3, ymm3        # ymm0 = (ymm3 * ymm3) + ymm0
	vfmadd231ps	ymm1, ymm4, ymm3        # ymm1 = (ymm4 * ymm3) + ymm1
	vfmadd231ps	ymm2, ymm4, ymm4        # ymm2 = (ymm4 * ymm4) + ymm2
	add	rbx, 32
	cmp	r10, rbx
	jne	.LBB0_21
.LBB0_22:                               # %middle.block291
                                        #   in Loop: Header=BB0_6 Depth=2
	vextractf128	xmm3, ymm2, 1
	vaddps	xmm2, xmm2, xmm3
	vpermilpd	xmm3, xmm2, 1           # xmm3 = xmm2[1,0]
	vaddps	xmm2, xmm2, xmm3
	vmovshdup	xmm3, xmm2              # xmm3 = xmm2[1,1,3,3]
	vaddss	xmm7, xmm2, xmm3
	vextractf128	xmm2, ymm1, 1
	vaddps	xmm1, xmm1, xmm2
	vpermilpd	xmm2, xmm1, 1           # xmm2 = xmm1[1,0]
	vaddps	xmm1, xmm1, xmm2
	vmovshdup	xmm2, xmm1              # xmm2 = xmm1[1,1,3,3]
	vaddss	xmm3, xmm1, xmm2
	vextractf128	xmm1, ymm0, 1
	vaddps	xmm0, xmm0, xmm1
	vpermilpd	xmm1, xmm0, 1           # xmm1 = xmm0[1,0]
	vaddps	xmm0, xmm0, xmm1
	vmovshdup	xmm1, xmm0              # xmm1 = xmm0[1,1,3,3]
	vaddss	xmm0, xmm0, xmm1
	cmp	r11, rdi
	mov	r12, qword ptr [rbp - 64]       # 8-byte Reload
	vxorps	xmm13, xmm13, xmm13
	mov	r10, qword ptr [rbp - 56]       # 8-byte Reload
	mov	rbx, qword ptr [rbp - 48]       # 8-byte Reload
	je	.LBB0_38
.LBB0_23:                               # %scalar.ph292
                                        #   in Loop: Header=BB0_6 Depth=2
	imul	r8, r13
	add	rcx, r8
.LBB0_24:                               # %L54
                                        #   Parent Loop BB0_4 Depth=1
                                        #     Parent Loop BB0_6 Depth=2
                                        # =>    This Inner Loop Header: Depth=3
	vmovss	xmm1, dword ptr [rcx + 4*rdi]   # xmm1 = mem[0],zero,zero,zero
	vmovss	xmm2, dword ptr [rsi + 4*rdi]   # xmm2 = mem[0],zero,zero,zero
	vfmadd231ss	xmm0, xmm1, xmm1        # xmm0 = (xmm1 * xmm1) + xmm0
	vfmadd231ss	xmm3, xmm2, xmm1        # xmm3 = (xmm2 * xmm1) + xmm3
	vfmadd231ss	xmm7, xmm2, xmm2        # xmm7 = (xmm2 * xmm2) + xmm7
	inc	rdi
	cmp	r11, rdi
	jne	.LBB0_24
	jmp	.LBB0_38
	.p2align	4, 0x90
.LBB0_73:                               # %L338
                                        #   in Loop: Header=BB0_4 Depth=1
	mov	rax, qword ptr [rbp - 120]      # 8-byte Reload
	cmp	rax, qword ptr [rbp - 112]      # 8-byte Folded Reload
	je	.LBB0_74
# %bb.3:                                # %L17thread-pre-split
                                        #   in Loop: Header=BB0_4 Depth=1
	inc	rax
	mov	r15, qword ptr [r10 + 8]
	jmp	.LBB0_4
.LBB0_74:
	mov	rcx, qword ptr [rbp - 104]      # 8-byte Reload
.LBB0_75:                               # %L349
	mov	rax, qword ptr [rbp - 88]
	mov	qword ptr [rcx], rax
	vmovaps	xmm0, xmm1
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
	jge	.LBB0_76
.LBB0_9:                                # %oob
                                        # =>This Inner Loop Header: Depth=1
	xor	qword ptr [rsp], 0
	sub	rsp, 4096
	cmp	rsi, rsp
	jl	.LBB0_9
.LBB0_76:                               # %oob
	mov	rsp, rsi
	mov	qword ptr [rsi], r14
	movabs	rax, offset ijl_bounds_error_ints
	mov	edx, 1
	vzeroupper
	call	rax
.LBB0_39:                               # %oob44
	mov	rsi, rsp
	mov	eax, 16
	sub	rsi, rax
	cmp	rsi, rsp
	jge	.LBB0_77
.LBB0_41:                               # %oob44
                                        # =>This Inner Loop Header: Depth=1
	xor	qword ptr [rsp], 0
	sub	rsp, 4096
	cmp	rsi, rsp
	jl	.LBB0_41
.LBB0_77:                               # %oob44
	mov	rsp, rsi
	mov	qword ptr [rsi], r14
	movabs	rax, offset ijl_bounds_error_ints
	mov	edx, 1
	mov	rdi, r10
	vzeroupper
	call	rax
.LBB0_82:                               # %L148
	movabs	rax, offset j_throw_complex_domainerror_1647
	movabs	rdi, 140312453360144
	vzeroupper
	call	rax
.LBB0_83:                               # %L213
	movabs	rax, offset j_throw_complex_domainerror_1647
	movabs	rdi, 140312453360144
	vzeroupper
	call	rax
.LBB0_84:                               # %L220
	movabs	rax, offset j_throw_complex_domainerror_1647
	movabs	rdi, 140312453360144
	vmovaps	xmm0, xmm4
	vzeroupper
	call	rax
.LBB0_85:                               # %L227
	movabs	rax, offset j_throw_complex_domainerror_1647
	movabs	rdi, 140312453360144
	vmovaps	xmm0, xmm5
	vzeroupper
	call	rax
.Lfunc_end0:
	.size	julia_pass_1644, .Lfunc_end0-julia_pass_1644
                                        # -- End function
	.section	".note.GNU-stack","",@progbits
