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
	sub	rsp, 184
	vxorps	xmm0, xmm0, xmm0
	vmovaps	xmmword ptr [rbp - 112], xmm0
	mov	qword ptr [rbp - 96], 0
	#APP
	mov	rax, qword ptr fs:[0]
	#NO_APP
	mov	rcx, qword ptr [rax - 8]
	mov	qword ptr [rbp - 112], 4
	mov	rax, qword ptr [rcx]
	mov	qword ptr [rbp - 104], rax
	lea	rax, [rbp - 112]
	mov	qword ptr [rcx], rax
	xor	eax, eax
	test	rdx, rdx
	cmovg	rax, rdx
	mov	qword ptr [rbp - 144], rax      # 8-byte Spill
	jle	.LBB0_1
# %bb.2:                                # %L17.preheader
	mov	rbx, rsi
	mov	r10, qword ptr [rsi + 8]
	test	r10, r10
	je	.LBB0_3
# %bb.4:                                # %L17.preheader473
	mov	r15, rdi
	mov	qword ptr [rbp - 136], rcx      # 8-byte Spill
	mov	r12, qword ptr [rdi]
	vxorps	xmm13, xmm13, xmm13
	mov	eax, 1
	movabs	rcx, offset .LCPI0_1
	vbroadcastss	ymm0, dword ptr [rcx]
	vmovups	ymmword ptr [rbp - 224], ymm0   # 32-byte Spill
	movabs	rcx, offset .LCPI0_0
	vmovaps	ymm0, ymmword ptr [rcx]
	vmovups	ymmword ptr [rbp - 192], ymm0   # 32-byte Spill
                                        # implicit-def: $rcx
                                        # kill: killed $rcx
                                        # implicit-def: $rcx
                                        # kill: killed $rcx
	vxorps	xmm12, xmm12, xmm12
	mov	qword ptr [rbp - 80], rdi       # 8-byte Spill
	mov	qword ptr [rbp - 56], rbx       # 8-byte Spill
	.p2align	4, 0x90
.LBB0_6:                                # %L17
                                        # =>This Loop Header: Depth=1
                                        #     Child Loop BB0_8 Depth 2
                                        #       Child Loop BB0_20 Depth 3
                                        #       Child Loop BB0_23 Depth 3
                                        #       Child Loop BB0_26 Depth 3
                                        #       Child Loop BB0_34 Depth 3
                                        #       Child Loop BB0_39 Depth 3
                                        #       Child Loop BB0_58 Depth 3
                                        #       Child Loop BB0_53 Depth 3
	mov	qword ptr [rbp - 152], rax      # 8-byte Spill
	test	r10, r10
	je	.LBB0_73
# %bb.7:                                # %L31.preheader
                                        #   in Loop: Header=BB0_6 Depth=1
	mov	r14d, 1
	xor	r13d, r13d
	mov	qword ptr [rbp - 64], r10       # 8-byte Spill
	jmp	.LBB0_8
	.p2align	4, 0x90
.LBB0_71:                               # %L291
                                        #   in Loop: Header=BB0_8 Depth=2
	mov	qword ptr [rbp - 96], r12
	mov	rdi, r15
	mov	rsi, r14
	vmovss	dword ptr [rbp - 84], xmm12     # 4-byte Spill
	movabs	rax, offset j__sqrt_cold_1895
	vzeroupper
	call	rax
	mov	rbx, qword ptr [rbp - 56]       # 8-byte Reload
	mov	r10, qword ptr [rbp - 64]       # 8-byte Reload
	vxorps	xmm13, xmm13, xmm13
	vmovss	xmm12, dword ptr [rbp - 84]     # 4-byte Reload
                                        # xmm12 = mem[0],zero,zero,zero
	vmovaps	xmm2, xmm0
.LBB0_72:                               # %L295
                                        #   in Loop: Header=BB0_8 Depth=2
	vaddss	xmm12, xmm12, xmm2
	lea	rax, [r14 + 1]
	add	r13, 4
	cmp	r14, r10
	mov	r14, rax
	je	.LBB0_73
.LBB0_8:                                # %L31
                                        #   Parent Loop BB0_6 Depth=1
                                        # =>  This Loop Header: Depth=2
                                        #       Child Loop BB0_20 Depth 3
                                        #       Child Loop BB0_23 Depth 3
                                        #       Child Loop BB0_26 Depth 3
                                        #       Child Loop BB0_34 Depth 3
                                        #       Child Loop BB0_39 Depth 3
                                        #       Child Loop BB0_58 Depth 3
                                        #       Child Loop BB0_53 Depth 3
	mov	rdi, qword ptr [r12 + 32]
	lea	r9, [r14 - 1]
	cmp	r9, qword ptr [rdi + 8]
	jae	.LBB0_9
# %bb.12:                               # %idxend
                                        #   in Loop: Header=BB0_8 Depth=2
	mov	rsi, qword ptr [r12]
	mov	rax, qword ptr [r12 + 24]
	mov	rcx, qword ptr [rdi]
	vmovss	xmm1, dword ptr [rcx + 4*r14 - 4] # xmm1 = mem[0],zero,zero,zero
	vucomiss	xmm1, xmm1
	mov	r11, qword ptr [rax + 8]
	jp	.LBB0_13
# %bb.27:                               # %L83
                                        #   in Loop: Header=BB0_8 Depth=2
	test	r11, r11
	je	.LBB0_28
# %bb.29:                               # %L96.lr.ph
                                        #   in Loop: Header=BB0_8 Depth=2
	mov	rdx, qword ptr [rsi]
	mov	r8, qword ptr [rsi + 24]
	mov	rsi, qword ptr [rax]
	cmp	r11, 16
	jae	.LBB0_31
# %bb.30:                               #   in Loop: Header=BB0_8 Depth=2
	vxorps	xmm7, xmm7, xmm7
	xor	edi, edi
	vxorps	xmm3, xmm3, xmm3
	jmp	.LBB0_38
	.p2align	4, 0x90
.LBB0_28:                               #   in Loop: Header=BB0_8 Depth=2
	vxorps	xmm3, xmm3, xmm3
	vxorps	xmm7, xmm7, xmm7
	jmp	.LBB0_40
	.p2align	4, 0x90
.LBB0_31:                               # %vector.ph367
                                        #   in Loop: Header=BB0_8 Depth=2
	mov	rdi, r11
	movabs	rax, 9223372036854775792
	and	rdi, rax
	lea	rax, [rdi - 16]
	mov	r10, rax
	shr	r10, 4
	inc	r10
	test	rax, rax
	je	.LBB0_32
# %bb.33:                               # %vector.ph367.new
                                        #   in Loop: Header=BB0_8 Depth=2
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
	vmovaps	ymm0, ymmword ptr [rax]
	xor	eax, eax
	vmovaps	ymm3, ymm0
	vmovaps	ymm4, ymm2
	.p2align	4, 0x90
.LBB0_34:                               # %vector.body372
                                        #   Parent Loop BB0_6 Depth=1
                                        #     Parent Loop BB0_8 Depth=2
                                        # =>    This Inner Loop Header: Depth=3
	vmovups	ymm5, ymmword ptr [rsi + 4*rax]
	vmovups	ymm6, ymmword ptr [rsi + 4*rax + 32]
	vmovups	ymm7, ymmword ptr [rsi + 4*rax + 64]
	vmovups	ymm8, ymmword ptr [rsi + 4*rax + 96]
	vfmadd231ps	ymm0, ymm5, ymmword ptr [rcx + 4*rax - 96] # ymm0 = (ymm5 * mem) + ymm0
	vfmadd231ps	ymm2, ymm6, ymmword ptr [rcx + 4*rax - 64] # ymm2 = (ymm6 * mem) + ymm2
	vfmadd231ps	ymm3, ymm5, ymm5        # ymm3 = (ymm5 * ymm5) + ymm3
	vfmadd231ps	ymm4, ymm6, ymm6        # ymm4 = (ymm6 * ymm6) + ymm4
	vfmadd231ps	ymm0, ymm7, ymmword ptr [rcx + 4*rax - 32] # ymm0 = (ymm7 * mem) + ymm0
	vfmadd231ps	ymm2, ymm8, ymmword ptr [rcx + 4*rax] # ymm2 = (ymm8 * mem) + ymm2
	vfmadd231ps	ymm3, ymm7, ymm7        # ymm3 = (ymm7 * ymm7) + ymm3
	vfmadd231ps	ymm4, ymm8, ymm8        # ymm4 = (ymm8 * ymm8) + ymm4
	add	rax, 32
	add	rbx, -2
	jne	.LBB0_34
# %bb.35:                               # %middle.block364.unr-lcssa
                                        #   in Loop: Header=BB0_8 Depth=2
	test	r10b, 1
	je	.LBB0_37
.LBB0_36:                               # %vector.body372.epil.preheader
                                        #   in Loop: Header=BB0_8 Depth=2
	mov	rcx, r8
	imul	rcx, r9
	add	rcx, rax
	vmovups	ymm5, ymmword ptr [rsi + 4*rax]
	vmovups	ymm6, ymmword ptr [rsi + 4*rax + 32]
	vfmadd231ps	ymm0, ymm5, ymmword ptr [rdx + 4*rcx] # ymm0 = (ymm5 * mem) + ymm0
	vfmadd231ps	ymm2, ymm6, ymmword ptr [rdx + 4*rcx + 32] # ymm2 = (ymm6 * mem) + ymm2
	vfmadd231ps	ymm3, ymm5, ymm5        # ymm3 = (ymm5 * ymm5) + ymm3
	vfmadd231ps	ymm4, ymm6, ymm6        # ymm4 = (ymm6 * ymm6) + ymm4
.LBB0_37:                               # %middle.block364
                                        #   in Loop: Header=BB0_8 Depth=2
	vaddps	ymm0, ymm2, ymm0
	vaddps	ymm2, ymm4, ymm3
	vextractf128	xmm3, ymm2, 1
	vaddps	xmm2, xmm2, xmm3
	vpermilpd	xmm3, xmm2, 1           # xmm3 = xmm2[1,0]
	vaddps	xmm2, xmm2, xmm3
	vmovshdup	xmm3, xmm2              # xmm3 = xmm2[1,1,3,3]
	vaddss	xmm3, xmm2, xmm3
	vextractf128	xmm2, ymm0, 1
	vaddps	xmm0, xmm0, xmm2
	vpermilpd	xmm2, xmm0, 1           # xmm2 = xmm0[1,0]
	vaddps	xmm0, xmm0, xmm2
	vmovshdup	xmm2, xmm0              # xmm2 = xmm0[1,1,3,3]
	vaddss	xmm7, xmm0, xmm2
	cmp	r11, rdi
	mov	r15, qword ptr [rbp - 80]       # 8-byte Reload
	mov	r10, qword ptr [rbp - 64]       # 8-byte Reload
	mov	rbx, qword ptr [rbp - 56]       # 8-byte Reload
	je	.LBB0_40
.LBB0_38:                               # %scalar.ph365
                                        #   in Loop: Header=BB0_8 Depth=2
	imul	r8, r13
	add	rdx, r8
	.p2align	4, 0x90
.LBB0_39:                               # %L96
                                        #   Parent Loop BB0_6 Depth=1
                                        #     Parent Loop BB0_8 Depth=2
                                        # =>    This Inner Loop Header: Depth=3
	vmovss	xmm0, dword ptr [rsi + 4*rdi]   # xmm0 = mem[0],zero,zero,zero
	vfmadd231ss	xmm7, xmm0, dword ptr [rdx + 4*rdi] # xmm7 = (xmm0 * mem) + xmm7
	vfmadd231ss	xmm3, xmm0, xmm0        # xmm3 = (xmm0 * xmm0) + xmm3
	inc	rdi
	cmp	r11, rdi
	jne	.LBB0_39
.LBB0_40:                               # %L124
                                        #   in Loop: Header=BB0_8 Depth=2
	cmp	r9, qword ptr [rbx + 8]
	jae	.LBB0_41
# %bb.79:                               # %idxend46
                                        #   in Loop: Header=BB0_8 Depth=2
	mov	rax, qword ptr [rbx]
	vmovss	xmm0, dword ptr [rax + 4*r14 - 4] # xmm0 = mem[0],zero,zero,zero
	vsubss	xmm2, xmm1, xmm1
	vucomiss	xmm2, xmm2
	jp	.LBB0_71
# %bb.80:                               # %idxend46
                                        #   in Loop: Header=BB0_8 Depth=2
	mov	rdx, qword ptr [r15]
	mov	rax, qword ptr [rdx + 24]
	mov	rcx, qword ptr [rax + 8]
	vcvtsi2ss	xmm2, xmm14, rcx
	movabs	rsi, offset .LCPI0_2
	vmulss	xmm2, xmm2, dword ptr [rsi]
	vucomiss	xmm1, xmm2
	jb	.LBB0_71
# %bb.81:                               # %idxend46
                                        #   in Loop: Header=BB0_8 Depth=2
	vsubss	xmm4, xmm3, xmm3
	vucomiss	xmm4, xmm4
	jp	.LBB0_71
# %bb.82:                               # %idxend46
                                        #   in Loop: Header=BB0_8 Depth=2
	vucomiss	xmm3, xmm2
	jb	.LBB0_71
# %bb.44:                               # %L148
                                        #   in Loop: Header=BB0_8 Depth=2
	vucomiss	xmm13, xmm1
	ja	.LBB0_83
# %bb.45:                               # %L152
                                        #   in Loop: Header=BB0_8 Depth=2
	vmovss	xmm4, dword ptr [r15 + 8]       # xmm4 = mem[0],zero,zero,zero
	vsqrtss	xmm5, xmm1, xmm1
	vxorps	xmm2, xmm2, xmm2
	vucomiss	xmm4, xmm5
	jae	.LBB0_72
# %bb.46:                               # %L157
                                        #   in Loop: Header=BB0_8 Depth=2
	vdivss	xmm6, xmm7, xmm1
	vmulss	xmm1, xmm7, xmm6
	vsubss	xmm1, xmm3, xmm1
	movabs	rsi, offset .LCPI0_3
	vmulss	xmm2, xmm3, dword ptr [rsi]
	vucomiss	xmm2, xmm1
	jbe	.LBB0_63
# %bb.47:                               # %L163
                                        #   in Loop: Header=BB0_8 Depth=2
	mov	rdi, qword ptr [rdx]
	mov	rdx, qword ptr [rdi + 24]
	mov	qword ptr [rbp - 48], rdx       # 8-byte Spill
	cmp	r9, qword ptr [rdi + 32]
	jae	.LBB0_84
# %bb.48:                               # %L184
                                        #   in Loop: Header=BB0_8 Depth=2
	test	rcx, rcx
	je	.LBB0_49
# %bb.50:                               # %L208.lr.ph
                                        #   in Loop: Header=BB0_8 Depth=2
	mov	rax, qword ptr [rax]
	mov	r10, qword ptr [rdi]
	cmp	rcx, 16
	jae	.LBB0_55
# %bb.51:                               #   in Loop: Header=BB0_8 Depth=2
	vxorps	xmm1, xmm1, xmm1
	xor	esi, esi
	jmp	.LBB0_52
.LBB0_32:                               #   in Loop: Header=BB0_8 Depth=2
	xor	eax, eax
	vmovups	ymm3, ymmword ptr [rbp - 192]   # 32-byte Reload
	vmovaps	ymm0, ymm3
	vmovups	ymm4, ymmword ptr [rbp - 224]   # 32-byte Reload
	vmovaps	ymm2, ymm4
	test	r10b, 1
	je	.LBB0_37
	jmp	.LBB0_36
.LBB0_49:                               #   in Loop: Header=BB0_8 Depth=2
	vxorps	xmm1, xmm1, xmm1
	mov	qword ptr [rbp - 72], r14       # 8-byte Spill
	jmp	.LBB0_64
.LBB0_55:                               # %vector.ph
                                        #   in Loop: Header=BB0_8 Depth=2
	mov	rsi, rcx
	movabs	rdx, 9223372036854775792
	and	rsi, rdx
	vbroadcastss	ymm1, xmm6
	lea	rdx, [rsi - 16]
	mov	r8, rdx
	shr	r8, 4
	inc	r8
	test	rdx, rdx
	je	.LBB0_56
# %bb.57:                               # %vector.ph.new
                                        #   in Loop: Header=BB0_8 Depth=2
	mov	rdi, r8
	movabs	rdx, 2305843009213693950
	and	rdi, rdx
	mov	rdx, qword ptr [rbp - 48]       # 8-byte Reload
	imul	rdx, r13
	add	rdx, r10
	add	rdx, 96
	movabs	rbx, offset .LCPI0_1
	vbroadcastss	ymm2, dword ptr [rbx]
	movabs	rbx, offset .LCPI0_0
	vmovaps	ymm3, ymmword ptr [rbx]
	xor	ebx, ebx
	.p2align	4, 0x90
.LBB0_58:                               # %vector.body
                                        #   Parent Loop BB0_6 Depth=1
                                        #     Parent Loop BB0_8 Depth=2
                                        # =>    This Inner Loop Header: Depth=3
	vmulps	ymm7, ymm1, ymmword ptr [rdx + 4*rbx - 96]
	vmulps	ymm8, ymm1, ymmword ptr [rdx + 4*rbx - 64]
	vmovups	ymm9, ymmword ptr [rax + 4*rbx]
	vsubps	ymm7, ymm9, ymm7
	vmovups	ymm9, ymmword ptr [rax + 4*rbx + 32]
	vsubps	ymm8, ymm9, ymm8
	vmovups	ymm9, ymmword ptr [rax + 4*rbx + 64]
	vmovups	ymm10, ymmword ptr [rax + 4*rbx + 96]
	vfmadd213ps	ymm7, ymm7, ymm3        # ymm7 = (ymm7 * ymm7) + ymm3
	vfmadd213ps	ymm8, ymm8, ymm2        # ymm8 = (ymm8 * ymm8) + ymm2
	vmulps	ymm2, ymm1, ymmword ptr [rdx + 4*rbx - 32]
	vmulps	ymm11, ymm1, ymmword ptr [rdx + 4*rbx]
	vsubps	ymm3, ymm9, ymm2
	vsubps	ymm2, ymm10, ymm11
	vfmadd213ps	ymm3, ymm3, ymm7        # ymm3 = (ymm3 * ymm3) + ymm7
	vfmadd213ps	ymm2, ymm2, ymm8        # ymm2 = (ymm2 * ymm2) + ymm8
	add	rbx, 32
	add	rdi, -2
	jne	.LBB0_58
# %bb.59:                               # %middle.block.unr-lcssa
                                        #   in Loop: Header=BB0_8 Depth=2
	test	r8b, 1
	je	.LBB0_61
.LBB0_60:                               # %vector.body.epil.preheader
                                        #   in Loop: Header=BB0_8 Depth=2
	imul	r9, qword ptr [rbp - 48]        # 8-byte Folded Reload
	vmovups	ymm7, ymmword ptr [rax + 4*rbx]
	vmovups	ymm8, ymmword ptr [rax + 4*rbx + 32]
	add	r9, rbx
	vmulps	ymm9, ymm1, ymmword ptr [r10 + 4*r9]
	vsubps	ymm7, ymm7, ymm9
	vmulps	ymm1, ymm1, ymmword ptr [r10 + 4*r9 + 32]
	vsubps	ymm1, ymm8, ymm1
	vfmadd231ps	ymm3, ymm7, ymm7        # ymm3 = (ymm7 * ymm7) + ymm3
	vfmadd231ps	ymm2, ymm1, ymm1        # ymm2 = (ymm1 * ymm1) + ymm2
.LBB0_61:                               # %middle.block
                                        #   in Loop: Header=BB0_8 Depth=2
	vaddps	ymm1, ymm2, ymm3
	vextractf128	xmm2, ymm1, 1
	vaddps	xmm1, xmm1, xmm2
	vpermilpd	xmm2, xmm1, 1           # xmm2 = xmm1[1,0]
	vaddps	xmm1, xmm1, xmm2
	vmovshdup	xmm2, xmm1              # xmm2 = xmm1[1,1,3,3]
	vaddss	xmm1, xmm1, xmm2
	cmp	rcx, rsi
	mov	r15, qword ptr [rbp - 80]       # 8-byte Reload
	jne	.LBB0_52
# %bb.62:                               #   in Loop: Header=BB0_8 Depth=2
	mov	qword ptr [rbp - 72], r14       # 8-byte Spill
	mov	r10, qword ptr [rbp - 64]       # 8-byte Reload
	mov	rbx, qword ptr [rbp - 56]       # 8-byte Reload
	jmp	.LBB0_63
.LBB0_52:                               # %scalar.ph
                                        #   in Loop: Header=BB0_8 Depth=2
	mov	rdx, qword ptr [rbp - 48]       # 8-byte Reload
	imul	rdx, r13
	add	r10, rdx
	.p2align	4, 0x90
.LBB0_53:                               # %L208
                                        #   Parent Loop BB0_6 Depth=1
                                        #     Parent Loop BB0_8 Depth=2
                                        # =>    This Inner Loop Header: Depth=3
	vmovss	xmm2, dword ptr [rax + 4*rsi]   # xmm2 = mem[0],zero,zero,zero
	vmulss	xmm3, xmm6, dword ptr [r10 + 4*rsi]
	vsubss	xmm2, xmm2, xmm3
	vfmadd231ss	xmm1, xmm2, xmm2        # xmm1 = (xmm2 * xmm2) + xmm1
	inc	rsi
	cmp	rcx, rsi
	jne	.LBB0_53
# %bb.54:                               #   in Loop: Header=BB0_8 Depth=2
	mov	qword ptr [rbp - 72], r14       # 8-byte Spill
	mov	r10, qword ptr [rbp - 64]       # 8-byte Reload
	mov	rbx, qword ptr [rbp - 56]       # 8-byte Reload
.LBB0_63:                               # %L245
                                        #   in Loop: Header=BB0_8 Depth=2
	vucomiss	xmm13, xmm1
	ja	.LBB0_85
.LBB0_64:                               # %L252
                                        #   in Loop: Header=BB0_8 Depth=2
	vsubss	xmm2, xmm5, xmm4
	vucomiss	xmm13, xmm2
	ja	.LBB0_86
# %bb.65:                               # %L259
                                        #   in Loop: Header=BB0_8 Depth=2
	vaddss	xmm3, xmm5, xmm4
	vucomiss	xmm13, xmm3
	ja	.LBB0_87
# %bb.66:                               # %L266
                                        #   in Loop: Header=BB0_8 Depth=2
	vaddss	xmm6, xmm6, xmm0
	vdivss	xmm0, xmm4, xmm5
	vsqrtss	xmm1, xmm1, xmm1
	vsqrtss	xmm2, xmm2, xmm2
	vsqrtss	xmm3, xmm3, xmm3
	vmulss	xmm2, xmm2, xmm3
	vdivss	xmm1, xmm1, xmm2
	vmulss	xmm3, xmm0, xmm1
	vsubss	xmm0, xmm6, xmm3
	vmovd	eax, xmm0
	vxorps	xmm1, xmm1, xmm1
	vmovaps	xmm2, xmm0
	test	eax, eax
	jns	.LBB0_68
# %bb.67:                               # %L266
                                        #   in Loop: Header=BB0_8 Depth=2
	vxorps	xmm2, xmm2, xmm2
.LBB0_68:                               # %L266
                                        #   in Loop: Header=BB0_8 Depth=2
	vaddss	xmm3, xmm6, xmm3
	vmovd	eax, xmm3
	test	eax, eax
	jns	.LBB0_70
# %bb.69:                               # %L266
                                        #   in Loop: Header=BB0_8 Depth=2
	vmovaps	xmm1, xmm3
.LBB0_70:                               # %L266
                                        #   in Loop: Header=BB0_8 Depth=2
	vcmpordss	xmm4, xmm0, xmm0
	vblendvps	xmm0, xmm0, xmm2, xmm4
	vcmpordss	xmm2, xmm3, xmm3
	vblendvps	xmm1, xmm3, xmm1, xmm2
	vaddss	xmm2, xmm0, xmm1
	jmp	.LBB0_72
.LBB0_56:                               #   in Loop: Header=BB0_8 Depth=2
	movabs	rdx, offset .LCPI0_1
	vbroadcastss	ymm2, dword ptr [rdx]
	movabs	rdx, offset .LCPI0_0
	vmovaps	ymm3, ymmword ptr [rdx]
	xor	ebx, ebx
	test	r8b, 1
	je	.LBB0_61
	jmp	.LBB0_60
.LBB0_13:                               # %L40
                                        #   in Loop: Header=BB0_8 Depth=2
	test	r11, r11
	je	.LBB0_14
# %bb.15:                               # %L54.lr.ph
                                        #   in Loop: Header=BB0_8 Depth=2
	mov	rcx, qword ptr [rsi]
	mov	r8, qword ptr [rsi + 24]
	mov	rsi, qword ptr [rax]
	cmp	r11, 8
	jae	.LBB0_17
# %bb.16:                               #   in Loop: Header=BB0_8 Depth=2
	vxorps	xmm1, xmm1, xmm1
	xor	edi, edi
	vxorps	xmm7, xmm7, xmm7
	vxorps	xmm3, xmm3, xmm3
	jmp	.LBB0_25
.LBB0_14:                               #   in Loop: Header=BB0_8 Depth=2
	vxorps	xmm3, xmm3, xmm3
	vxorps	xmm7, xmm7, xmm7
	vxorps	xmm1, xmm1, xmm1
	jmp	.LBB0_40
.LBB0_17:                               # %vector.ph390
                                        #   in Loop: Header=BB0_8 Depth=2
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
	jae	.LBB0_19
# %bb.18:                               #   in Loop: Header=BB0_8 Depth=2
	movabs	rax, offset .LCPI0_0
	vmovaps	ymm0, ymmword ptr [rax]
	xor	ebx, ebx
	vmovaps	ymm1, ymm0
	vmovaps	ymm2, ymm0
	jmp	.LBB0_21
.LBB0_19:                               # %vector.ph390.new
                                        #   in Loop: Header=BB0_8 Depth=2
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
.LBB0_20:                               # %vector.body395
                                        #   Parent Loop BB0_6 Depth=1
                                        #     Parent Loop BB0_8 Depth=2
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
	jne	.LBB0_20
.LBB0_21:                               # %middle.block387.unr-lcssa
                                        #   in Loop: Header=BB0_8 Depth=2
	test	r10, r10
	je	.LBB0_24
# %bb.22:                               # %vector.body395.epil.preheader
                                        #   in Loop: Header=BB0_8 Depth=2
	lea	rax, [rsi + 4*rbx]
	lea	rbx, [rcx + 4*rbx]
	mov	rdx, r8
	imul	rdx, r13
	add	rdx, rbx
	shl	r10, 5
	xor	ebx, ebx
.LBB0_23:                               # %vector.body395.epil
                                        #   Parent Loop BB0_6 Depth=1
                                        #     Parent Loop BB0_8 Depth=2
                                        # =>    This Inner Loop Header: Depth=3
	vmovups	ymm3, ymmword ptr [rdx + rbx]
	vmovups	ymm4, ymmword ptr [rax + rbx]
	vfmadd231ps	ymm0, ymm3, ymm3        # ymm0 = (ymm3 * ymm3) + ymm0
	vfmadd231ps	ymm1, ymm4, ymm3        # ymm1 = (ymm4 * ymm3) + ymm1
	vfmadd231ps	ymm2, ymm4, ymm4        # ymm2 = (ymm4 * ymm4) + ymm2
	add	rbx, 32
	cmp	r10, rbx
	jne	.LBB0_23
.LBB0_24:                               # %middle.block387
                                        #   in Loop: Header=BB0_8 Depth=2
	vextractf128	xmm3, ymm2, 1
	vaddps	xmm2, xmm2, xmm3
	vpermilpd	xmm3, xmm2, 1           # xmm3 = xmm2[1,0]
	vaddps	xmm2, xmm2, xmm3
	vmovshdup	xmm3, xmm2              # xmm3 = xmm2[1,1,3,3]
	vaddss	xmm3, xmm2, xmm3
	vextractf128	xmm2, ymm1, 1
	vaddps	xmm1, xmm1, xmm2
	vpermilpd	xmm2, xmm1, 1           # xmm2 = xmm1[1,0]
	vaddps	xmm1, xmm1, xmm2
	vmovshdup	xmm2, xmm1              # xmm2 = xmm1[1,1,3,3]
	vaddss	xmm7, xmm1, xmm2
	vextractf128	xmm1, ymm0, 1
	vaddps	xmm0, xmm0, xmm1
	vpermilpd	xmm1, xmm0, 1           # xmm1 = xmm0[1,0]
	vaddps	xmm0, xmm0, xmm1
	vmovshdup	xmm1, xmm0              # xmm1 = xmm0[1,1,3,3]
	vaddss	xmm1, xmm0, xmm1
	cmp	r11, rdi
	mov	r15, qword ptr [rbp - 80]       # 8-byte Reload
	vxorps	xmm13, xmm13, xmm13
	mov	r10, qword ptr [rbp - 64]       # 8-byte Reload
	mov	rbx, qword ptr [rbp - 56]       # 8-byte Reload
	je	.LBB0_40
.LBB0_25:                               # %scalar.ph388
                                        #   in Loop: Header=BB0_8 Depth=2
	imul	r8, r13
	add	rcx, r8
.LBB0_26:                               # %L54
                                        #   Parent Loop BB0_6 Depth=1
                                        #     Parent Loop BB0_8 Depth=2
                                        # =>    This Inner Loop Header: Depth=3
	vmovss	xmm0, dword ptr [rcx + 4*rdi]   # xmm0 = mem[0],zero,zero,zero
	vmovss	xmm2, dword ptr [rsi + 4*rdi]   # xmm2 = mem[0],zero,zero,zero
	vfmadd231ss	xmm1, xmm0, xmm0        # xmm1 = (xmm0 * xmm0) + xmm1
	vfmadd231ss	xmm7, xmm2, xmm0        # xmm7 = (xmm2 * xmm0) + xmm7
	vfmadd231ss	xmm3, xmm2, xmm2        # xmm3 = (xmm2 * xmm2) + xmm3
	inc	rdi
	cmp	r11, rdi
	jne	.LBB0_26
	jmp	.LBB0_40
	.p2align	4, 0x90
.LBB0_73:                               # %L307
                                        #   in Loop: Header=BB0_6 Depth=1
	mov	rax, qword ptr [rbp - 152]      # 8-byte Reload
	cmp	rax, qword ptr [rbp - 144]      # 8-byte Folded Reload
	je	.LBB0_74
# %bb.5:                                # %L17thread-pre-split
                                        #   in Loop: Header=BB0_6 Depth=1
	inc	rax
	mov	r10, qword ptr [rbx + 8]
	jmp	.LBB0_6
.LBB0_74:
	mov	rcx, qword ptr [rbp - 136]      # 8-byte Reload
	mov	rdx, qword ptr [rbp - 72]       # 8-byte Reload
	jmp	.LBB0_75
.LBB0_1:
	vxorps	xmm12, xmm12, xmm12
	jmp	.LBB0_76
.LBB0_3:
	vxorps	xmm12, xmm12, xmm12
                                        # implicit-def: $rdx
                                        # implicit-def: $rax
                                        # kill: killed $rax
.LBB0_75:                               # %L318.loopexit
	mov	rax, qword ptr [rbp - 48]       # 8-byte Reload
	mov	qword ptr [rbp - 128], rax
	mov	qword ptr [rbp - 120], rdx
.LBB0_76:                               # %L318
	mov	rax, qword ptr [rbp - 104]
	mov	qword ptr [rcx], rax
	vmovaps	xmm0, xmm12
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
	jge	.LBB0_77
.LBB0_11:                               # %oob
                                        # =>This Inner Loop Header: Depth=1
	xor	qword ptr [rsp], 0
	sub	rsp, 4096
	cmp	rsi, rsp
	jl	.LBB0_11
.LBB0_77:                               # %oob
	mov	rsp, rsi
	mov	qword ptr [rsi], r14
	movabs	rax, offset ijl_bounds_error_ints
	mov	edx, 1
	vzeroupper
	call	rax
.LBB0_41:                               # %oob44
	mov	rsi, rsp
	mov	eax, 16
	sub	rsi, rax
	cmp	rsi, rsp
	jge	.LBB0_78
.LBB0_43:                               # %oob44
                                        # =>This Inner Loop Header: Depth=1
	xor	qword ptr [rsp], 0
	sub	rsp, 4096
	cmp	rsi, rsp
	jl	.LBB0_43
.LBB0_78:                               # %oob44
	mov	rsp, rsi
	mov	qword ptr [rsi], r14
	movabs	rax, offset ijl_bounds_error_ints
	mov	edx, 1
	mov	rdi, rbx
	vzeroupper
	call	rax
.LBB0_83:                               # %L150
	movabs	rax, offset j_throw_complex_domainerror_1892
	movabs	rdi, 140312453360144
	vmovaps	xmm0, xmm1
	vzeroupper
	call	rax
.LBB0_86:                               # %L257
	movabs	rax, offset j_throw_complex_domainerror_1892
	movabs	rdi, 140312453360144
	vmovaps	xmm0, xmm2
	vzeroupper
	call	rax
.LBB0_87:                               # %L264
	movabs	rax, offset j_throw_complex_domainerror_1892
	movabs	rdi, 140312453360144
	vmovaps	xmm0, xmm3
	vzeroupper
	call	rax
.LBB0_85:                               # %L250
	movabs	rax, offset j_throw_complex_domainerror_1892
	movabs	rdi, 140312453360144
	vmovaps	xmm0, xmm1
	vzeroupper
	call	rax
.LBB0_84:                               # %L181
	mov	rax, qword ptr [rbp - 48]       # 8-byte Reload
	mov	qword ptr [rbp - 128], rax
	mov	qword ptr [rbp - 120], r14
	mov	qword ptr [rbp - 96], rdi
	movabs	rax, offset j_throw_boundserror_1894
	lea	rsi, [rbp - 128]
	vzeroupper
	call	rax
.Lfunc_end0:
	.size	julia_pass_1889, .Lfunc_end0-julia_pass_1889
                                        # -- End function
	.section	".note.GNU-stack","",@progbits
