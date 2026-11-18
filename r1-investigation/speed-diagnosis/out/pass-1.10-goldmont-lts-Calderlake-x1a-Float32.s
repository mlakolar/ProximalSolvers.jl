	.text
	.file	"pass"
	.section	.rodata.cst32,"aM",@progbits,32
	.p2align	5                               # -- Begin function julia_pass_2112
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
	.long	0x7f7fffff                      # float 3.40282347E+38
.LCPI0_5:
	.long	0x00800000                      # float 1.17549435E-38
.LCPI0_6:
	.long	0x3f800000                      # float 1
	.text
	.globl	julia_pass_2112
	.p2align	4, 0x90
	.type	julia_pass_2112,@function
julia_pass_2112:                        # @julia_pass_2112
# %bb.0:                                # %top
	push	rbp
	mov	rbp, rsp
	push	r15
	push	r14
	push	r13
	push	r12
	push	rbx
	and	rsp, -32
	sub	rsp, 384
	mov	rbx, rsp
	vxorps	xmm0, xmm0, xmm0
	vmovaps	ymmword ptr [rbx + 64], ymm0
	mov	qword ptr [rbx + 104], 0
	mov	qword ptr [rbx + 96], 0
	#APP
	mov	rax, qword ptr fs:[0]
	#NO_APP
	mov	rcx, qword ptr [rax - 8]
	mov	qword ptr [rbx + 64], 16
	mov	rax, qword ptr [rcx]
	mov	qword ptr [rbx + 72], rax
	lea	rax, [rbx + 64]
	mov	qword ptr [rcx], rax
	xor	eax, eax
	test	rdx, rdx
	cmovg	rax, rdx
	mov	qword ptr [rbx + 184], rax      # 8-byte Spill
	jle	.LBB0_1
# %bb.2:                                # %L17.preheader
	mov	r14, rsi
	mov	qword ptr [rbx + 168], rcx      # 8-byte Spill
	mov	rdx, qword ptr [rsi + 8]
	test	rdx, rdx
	je	.LBB0_3
# %bb.4:                                # %L17.preheader514
	mov	r10, rdi
	mov	rsi, qword ptr [rdi]
	vxorps	xmm14, xmm14, xmm14
	mov	ecx, 1
	movabs	rax, offset .LCPI0_1
	vbroadcastss	ymm0, dword ptr [rax]
	vmovaps	ymmword ptr [rbx + 320], ymm0   # 32-byte Spill
	movabs	rax, offset .LCPI0_0
	vmovaps	ymm0, ymmword ptr [rax]
	vmovaps	ymmword ptr [rbx + 288], ymm0   # 32-byte Spill
	vxorps	xmm9, xmm9, xmm9
                                        # implicit-def: $rax
                                        # implicit-def: $r15
	mov	qword ptr [rbx + 40], rdi       # 8-byte Spill
	mov	qword ptr [rbx + 24], rsi       # 8-byte Spill
	mov	qword ptr [rbx + 176], r14      # 8-byte Spill
	test	rdx, rdx
	je	.LBB0_85
	.p2align	4, 0x90
.LBB0_7:                                # %L31.preheader
	mov	qword ptr [rbx + 192], rcx      # 8-byte Spill
	mov	r12d, 1
	xor	eax, eax
	mov	qword ptr [rbx + 32], rax       # 8-byte Spill
	mov	qword ptr [rbx + 200], rdx      # 8-byte Spill
	jmp	.LBB0_8
	.p2align	4, 0x90
.LBB0_82:                               # %L358
                                        #   in Loop: Header=BB0_8 Depth=1
	mov	qword ptr [rbx + 88], rdi
	mov	qword ptr [rbx + 208], rdi
	mov	qword ptr [rbx + 216], r15
	mov	qword ptr [rbx + 224], r12
	mov	qword ptr [rbx + 232], r9
	mov	qword ptr [rbx + 240], 1
	mov	qword ptr [rbx + 104], rsi
	mov	qword ptr [rbx + 96], rdx
	mov	rdi, r10
	lea	rsi, [rbx + 208]
	lea	rcx, [rbx + 48]
	mov	r8, r12
	movabs	rax, offset j__sqrt_cold_2118
	vzeroupper
	call	rax
	vxorps	xmm14, xmm14, xmm14
	mov	rsi, qword ptr [rbx + 24]       # 8-byte Reload
	mov	r10, qword ptr [rbx + 40]       # 8-byte Reload
	vmovaps	xmm3, xmm0
.LBB0_83:                               # %L362
                                        #   in Loop: Header=BB0_8 Depth=1
	vmovss	xmm9, dword ptr [rbx + 60]      # 4-byte Reload
                                        # xmm9 = mem[0],zero,zero,zero
	vaddss	xmm9, xmm9, xmm3
	lea	rax, [r12 + 1]
	add	qword ptr [rbx + 32], 4         # 8-byte Folded Spill
	mov	rcx, qword ptr [rbx + 200]      # 8-byte Reload
	cmp	r12, rcx
	mov	r12, rax
	je	.LBB0_84
.LBB0_8:                                # %L31
                                        # =>This Loop Header: Depth=1
                                        #     Child Loop BB0_20 Depth 2
                                        #     Child Loop BB0_23 Depth 2
                                        #     Child Loop BB0_26 Depth 2
                                        #     Child Loop BB0_37 Depth 2
                                        #     Child Loop BB0_32 Depth 2
                                        #     Child Loop BB0_60 Depth 2
                                        #     Child Loop BB0_65 Depth 2
	mov	rdi, qword ptr [rsi + 32]
	lea	r9, [r12 - 1]
	cmp	r9, qword ptr [rdi + 8]
	jae	.LBB0_9
# %bb.12:                               # %idxend
                                        #   in Loop: Header=BB0_8 Depth=1
	mov	rcx, qword ptr [rsi]
	mov	rax, qword ptr [rsi + 24]
	mov	rdx, qword ptr [rdi]
	vmovss	xmm1, dword ptr [rdx + 4*r12 - 4] # xmm1 = mem[0],zero,zero,zero
	vucomiss	xmm1, xmm1
	mov	r13, qword ptr [rax + 8]
	jp	.LBB0_13
# %bb.27:                               # %L83
                                        #   in Loop: Header=BB0_8 Depth=1
	test	r13, r13
	je	.LBB0_28
# %bb.29:                               # %L96.lr.ph
                                        #   in Loop: Header=BB0_8 Depth=1
	mov	r11, qword ptr [rcx]
	mov	r8, qword ptr [rcx + 24]
	mov	rsi, qword ptr [rax]
	cmp	r13, 16
	jae	.LBB0_34
# %bb.30:                               #   in Loop: Header=BB0_8 Depth=1
	vxorps	xmm5, xmm5, xmm5
	xor	edi, edi
	vxorps	xmm4, xmm4, xmm4
	jmp	.LBB0_31
	.p2align	4, 0x90
.LBB0_28:                               #   in Loop: Header=BB0_8 Depth=1
	vxorps	xmm4, xmm4, xmm4
	vxorps	xmm5, xmm5, xmm5
	jmp	.LBB0_42
	.p2align	4, 0x90
.LBB0_34:                               # %vector.ph403
                                        #   in Loop: Header=BB0_8 Depth=1
	mov	rdi, r13
	movabs	rax, 9223372036854775792
	and	rdi, rax
	lea	rax, [rdi - 16]
	mov	r10, rax
	shr	r10, 4
	inc	r10
	test	rax, rax
	je	.LBB0_35
# %bb.36:                               # %vector.ph403.new
                                        #   in Loop: Header=BB0_8 Depth=1
	mov	rcx, r10
	movabs	rax, 2305843009213693950
	and	rcx, rax
	mov	rax, r8
	imul	rax, qword ptr [rbx + 32]       # 8-byte Folded Reload
	lea	rdx, [r11 + rax]
	add	rdx, 96
	movabs	rax, offset .LCPI0_1
	vbroadcastss	ymm2, dword ptr [rax]
	movabs	rax, offset .LCPI0_0
	vmovaps	ymm0, ymmword ptr [rax]
	xor	eax, eax
	vmovaps	ymm3, ymm0
	vmovaps	ymm4, ymm2
	.p2align	4, 0x90
.LBB0_37:                               # %vector.body408
                                        #   Parent Loop BB0_8 Depth=1
                                        # =>  This Inner Loop Header: Depth=2
	vmovups	ymm5, ymmword ptr [rsi + 4*rax]
	vmovups	ymm6, ymmword ptr [rsi + 4*rax + 32]
	vmovups	ymm7, ymmword ptr [rsi + 4*rax + 64]
	vmovups	ymm8, ymmword ptr [rsi + 4*rax + 96]
	vfmadd231ps	ymm0, ymm5, ymmword ptr [rdx + 4*rax - 96] # ymm0 = (ymm5 * mem) + ymm0
	vfmadd231ps	ymm2, ymm6, ymmword ptr [rdx + 4*rax - 64] # ymm2 = (ymm6 * mem) + ymm2
	vfmadd231ps	ymm3, ymm5, ymm5        # ymm3 = (ymm5 * ymm5) + ymm3
	vfmadd231ps	ymm4, ymm6, ymm6        # ymm4 = (ymm6 * ymm6) + ymm4
	vfmadd231ps	ymm0, ymm7, ymmword ptr [rdx + 4*rax - 32] # ymm0 = (ymm7 * mem) + ymm0
	vfmadd231ps	ymm2, ymm8, ymmword ptr [rdx + 4*rax] # ymm2 = (ymm8 * mem) + ymm2
	vfmadd231ps	ymm3, ymm7, ymm7        # ymm3 = (ymm7 * ymm7) + ymm3
	vfmadd231ps	ymm4, ymm8, ymm8        # ymm4 = (ymm8 * ymm8) + ymm4
	add	rax, 32
	add	rcx, -2
	jne	.LBB0_37
# %bb.38:                               # %middle.block400.unr-lcssa
                                        #   in Loop: Header=BB0_8 Depth=1
	test	r10b, 1
	je	.LBB0_40
.LBB0_39:                               # %vector.body408.epil.preheader
                                        #   in Loop: Header=BB0_8 Depth=1
	mov	rcx, r8
	imul	rcx, r9
	add	rcx, rax
	vmovups	ymm5, ymmword ptr [rsi + 4*rax]
	vmovups	ymm6, ymmword ptr [rsi + 4*rax + 32]
	vfmadd231ps	ymm0, ymm5, ymmword ptr [r11 + 4*rcx] # ymm0 = (ymm5 * mem) + ymm0
	vfmadd231ps	ymm2, ymm6, ymmword ptr [r11 + 4*rcx + 32] # ymm2 = (ymm6 * mem) + ymm2
	vfmadd231ps	ymm3, ymm5, ymm5        # ymm3 = (ymm5 * ymm5) + ymm3
	vfmadd231ps	ymm4, ymm6, ymm6        # ymm4 = (ymm6 * ymm6) + ymm4
.LBB0_40:                               # %middle.block400
                                        #   in Loop: Header=BB0_8 Depth=1
	vaddps	ymm0, ymm2, ymm0
	vaddps	ymm2, ymm4, ymm3
	vextractf128	xmm3, ymm2, 1
	vaddps	xmm2, xmm2, xmm3
	vpermilpd	xmm3, xmm2, 1           # xmm3 = xmm2[1,0]
	vaddps	xmm2, xmm2, xmm3
	vmovshdup	xmm3, xmm2              # xmm3 = xmm2[1,1,3,3]
	vaddss	xmm4, xmm2, xmm3
	vextractf128	xmm2, ymm0, 1
	vaddps	xmm0, xmm0, xmm2
	vpermilpd	xmm2, xmm0, 1           # xmm2 = xmm0[1,0]
	vaddps	xmm0, xmm0, xmm2
	vmovshdup	xmm2, xmm0              # xmm2 = xmm0[1,1,3,3]
	vaddss	xmm5, xmm0, xmm2
	cmp	r13, rdi
	mov	r10, qword ptr [rbx + 40]       # 8-byte Reload
	jne	.LBB0_31
# %bb.41:                               #   in Loop: Header=BB0_8 Depth=1
	mov	rsi, qword ptr [rbx + 24]       # 8-byte Reload
	jmp	.LBB0_42
	.p2align	4, 0x90
.LBB0_31:                               # %scalar.ph401
                                        #   in Loop: Header=BB0_8 Depth=1
	imul	r8, qword ptr [rbx + 32]        # 8-byte Folded Reload
	add	r11, r8
	.p2align	4, 0x90
.LBB0_32:                               # %L96
                                        #   Parent Loop BB0_8 Depth=1
                                        # =>  This Inner Loop Header: Depth=2
	vmovss	xmm0, dword ptr [rsi + 4*rdi]   # xmm0 = mem[0],zero,zero,zero
	vfmadd231ss	xmm5, xmm0, dword ptr [r11 + 4*rdi] # xmm5 = (xmm0 * mem) + xmm5
	vfmadd231ss	xmm4, xmm0, xmm0        # xmm4 = (xmm0 * xmm0) + xmm4
	inc	rdi
	cmp	r13, rdi
	jne	.LBB0_32
# %bb.33:                               #   in Loop: Header=BB0_8 Depth=1
	mov	rsi, qword ptr [rbx + 24]       # 8-byte Reload
.LBB0_42:                               # %L124
                                        #   in Loop: Header=BB0_8 Depth=1
	cmp	r9, qword ptr [r14 + 8]
	jae	.LBB0_43
# %bb.90:                               # %idxend46
                                        #   in Loop: Header=BB0_8 Depth=1
	mov	rax, qword ptr [r10]
	mov	rdi, qword ptr [rax]
	mov	r15, qword ptr [rdi + 24]
	cmp	r9, qword ptr [rdi + 32]
	jae	.LBB0_91
# %bb.46:                               # %L148
                                        #   in Loop: Header=BB0_8 Depth=1
	mov	rcx, qword ptr [r14]
	vmovss	xmm0, dword ptr [rcx + 4*r12 - 4] # xmm0 = mem[0],zero,zero,zero
	imul	r9, r15
	mov	rdx, qword ptr [rax + 24]
	mov	r13d, dword ptr [r10 + 8]
	mov	dword ptr [rbx + 48], r13d
	vsubss	xmm2, xmm1, xmm1
	vucomiss	xmm2, xmm2
	vmovss	dword ptr [rbx + 60], xmm9      # 4-byte Spill
	jp	.LBB0_82
# %bb.47:                               # %L148
                                        #   in Loop: Header=BB0_8 Depth=1
	mov	r11, qword ptr [rdx + 8]
	vxorps	xmm12, xmm12, xmm12
	vcvtsi2ss	xmm2, xmm12, r11
	movabs	rax, offset .LCPI0_2
	vmulss	xmm2, xmm2, dword ptr [rax]
	vucomiss	xmm1, xmm2
	jb	.LBB0_82
# %bb.48:                               # %L148
                                        #   in Loop: Header=BB0_8 Depth=1
	vsubss	xmm3, xmm4, xmm4
	vucomiss	xmm3, xmm3
	jp	.LBB0_82
# %bb.49:                               # %L148
                                        #   in Loop: Header=BB0_8 Depth=1
	vucomiss	xmm4, xmm2
	jb	.LBB0_82
# %bb.50:                               # %L179
                                        #   in Loop: Header=BB0_8 Depth=1
	vucomiss	xmm14, xmm1
	ja	.LBB0_92
# %bb.51:                               # %L184
                                        #   in Loop: Header=BB0_8 Depth=1
	vmovd	xmm13, r13d
	vsqrtss	xmm7, xmm1, xmm1
	vxorps	xmm3, xmm3, xmm3
	vucomiss	xmm13, xmm7
	jae	.LBB0_83
# %bb.52:                               # %L189
                                        #   in Loop: Header=BB0_8 Depth=1
	vdivss	xmm15, xmm5, xmm1
	vmulss	xmm3, xmm15, xmm5
	vsubss	xmm3, xmm4, xmm3
	movabs	rax, offset .LCPI0_3
	vmulss	xmm4, xmm4, dword ptr [rax]
	vucomiss	xmm4, xmm3
	jbe	.LBB0_66
# %bb.53:                               # %L196
                                        #   in Loop: Header=BB0_8 Depth=1
	test	r11, r11
	je	.LBB0_54
# %bb.55:                               # %L208.lr.ph
                                        #   in Loop: Header=BB0_8 Depth=1
	mov	rax, qword ptr [rdx]
	mov	r8, qword ptr [rdi]
	cmp	r11, 16
	jae	.LBB0_57
# %bb.56:                               #   in Loop: Header=BB0_8 Depth=1
	vxorps	xmm3, xmm3, xmm3
	xor	ecx, ecx
	jmp	.LBB0_64
.LBB0_35:                               #   in Loop: Header=BB0_8 Depth=1
	xor	eax, eax
	vmovaps	ymm3, ymmword ptr [rbx + 288]   # 32-byte Reload
	vmovaps	ymm0, ymm3
	vmovaps	ymm4, ymmword ptr [rbx + 320]   # 32-byte Reload
	vmovaps	ymm2, ymm4
	test	r10b, 1
	je	.LBB0_40
	jmp	.LBB0_39
.LBB0_54:                               #   in Loop: Header=BB0_8 Depth=1
	vxorps	xmm3, xmm3, xmm3
	jmp	.LBB0_67
.LBB0_57:                               # %vector.ph
                                        #   in Loop: Header=BB0_8 Depth=1
	mov	rcx, r11
	movabs	rsi, 9223372036854775792
	and	rcx, rsi
	vbroadcastss	ymm3, xmm15
	lea	rsi, [rcx - 16]
	mov	r10, rsi
	shr	r10, 4
	inc	r10
	test	rsi, rsi
	mov	qword ptr [rbx + 144], r10      # 8-byte Spill
	je	.LBB0_58
# %bb.59:                               # %vector.ph.new
                                        #   in Loop: Header=BB0_8 Depth=1
	movabs	rsi, 2305843009213693950
	and	r10, rsi
	mov	rsi, r15
	imul	rsi, qword ptr [rbx + 32]       # 8-byte Folded Reload
	lea	r14, [r8 + rsi]
	add	r14, 96
	movabs	rsi, offset .LCPI0_1
	vbroadcastss	ymm4, dword ptr [rsi]
	movabs	rsi, offset .LCPI0_0
	vmovaps	ymm5, ymmword ptr [rsi]
	xor	esi, esi
	.p2align	4, 0x90
.LBB0_60:                               # %vector.body
                                        #   Parent Loop BB0_8 Depth=1
                                        # =>  This Inner Loop Header: Depth=2
	vmulps	ymm8, ymm3, ymmword ptr [r14 + 4*rsi - 96]
	vmulps	ymm9, ymm3, ymmword ptr [r14 + 4*rsi - 64]
	vmovups	ymm10, ymmword ptr [rax + 4*rsi]
	vsubps	ymm8, ymm10, ymm8
	vmovups	ymm10, ymmword ptr [rax + 4*rsi + 32]
	vsubps	ymm9, ymm10, ymm9
	vmovups	ymm10, ymmword ptr [rax + 4*rsi + 64]
	vmovups	ymm11, ymmword ptr [rax + 4*rsi + 96]
	vfmadd213ps	ymm8, ymm8, ymm5        # ymm8 = (ymm8 * ymm8) + ymm5
	vfmadd213ps	ymm9, ymm9, ymm4        # ymm9 = (ymm9 * ymm9) + ymm4
	vmulps	ymm4, ymm3, ymmword ptr [r14 + 4*rsi - 32]
	vmulps	ymm12, ymm3, ymmword ptr [r14 + 4*rsi]
	vsubps	ymm5, ymm10, ymm4
	vsubps	ymm4, ymm11, ymm12
	vfmadd213ps	ymm5, ymm5, ymm8        # ymm5 = (ymm5 * ymm5) + ymm8
	vfmadd213ps	ymm4, ymm4, ymm9        # ymm4 = (ymm4 * ymm4) + ymm9
	add	rsi, 32
	add	r10, -2
	jne	.LBB0_60
# %bb.61:                               # %middle.block.unr-lcssa
                                        #   in Loop: Header=BB0_8 Depth=1
	test	byte ptr [rbx + 144], 1         # 1-byte Folded Reload
	je	.LBB0_63
.LBB0_62:                               # %vector.body.epil.preheader
                                        #   in Loop: Header=BB0_8 Depth=1
	vmovups	ymm8, ymmword ptr [rax + 4*rsi]
	vmovups	ymm9, ymmword ptr [rax + 4*rsi + 32]
	add	rsi, r9
	vmulps	ymm10, ymm3, ymmword ptr [r8 + 4*rsi]
	vsubps	ymm8, ymm8, ymm10
	vmulps	ymm3, ymm3, ymmword ptr [r8 + 4*rsi + 32]
	vsubps	ymm3, ymm9, ymm3
	vfmadd231ps	ymm5, ymm8, ymm8        # ymm5 = (ymm8 * ymm8) + ymm5
	vfmadd231ps	ymm4, ymm3, ymm3        # ymm4 = (ymm3 * ymm3) + ymm4
.LBB0_63:                               # %middle.block
                                        #   in Loop: Header=BB0_8 Depth=1
	vaddps	ymm3, ymm4, ymm5
	vextractf128	xmm4, ymm3, 1
	vaddps	xmm3, xmm3, xmm4
	vpermilpd	xmm4, xmm3, 1           # xmm4 = xmm3[1,0]
	vaddps	xmm3, xmm3, xmm4
	vmovshdup	xmm4, xmm3              # xmm4 = xmm3[1,1,3,3]
	vaddss	xmm3, xmm3, xmm4
	cmp	r11, rcx
	mov	r14, qword ptr [rbx + 176]      # 8-byte Reload
	mov	r10, qword ptr [rbx + 40]       # 8-byte Reload
	mov	rsi, qword ptr [rbx + 24]       # 8-byte Reload
	je	.LBB0_66
.LBB0_64:                               # %scalar.ph
                                        #   in Loop: Header=BB0_8 Depth=1
	mov	rsi, r15
	imul	rsi, qword ptr [rbx + 32]       # 8-byte Folded Reload
	add	r8, rsi
	mov	rsi, qword ptr [rbx + 24]       # 8-byte Reload
	.p2align	4, 0x90
.LBB0_65:                               # %L208
                                        #   Parent Loop BB0_8 Depth=1
                                        # =>  This Inner Loop Header: Depth=2
	vmovss	xmm4, dword ptr [rax + 4*rcx]   # xmm4 = mem[0],zero,zero,zero
	vmulss	xmm5, xmm15, dword ptr [r8 + 4*rcx]
	vsubss	xmm4, xmm4, xmm5
	vfmadd231ss	xmm3, xmm4, xmm4        # xmm3 = (xmm4 * xmm4) + xmm3
	inc	rcx
	cmp	r11, rcx
	jne	.LBB0_65
.LBB0_66:                               # %L245
                                        #   in Loop: Header=BB0_8 Depth=1
	vucomiss	xmm14, xmm3
	ja	.LBB0_93
.LBB0_67:                               # %L250
                                        #   in Loop: Header=BB0_8 Depth=1
	vsubss	xmm4, xmm7, xmm13
	vucomiss	xmm14, xmm4
	ja	.LBB0_94
# %bb.68:                               # %L257
                                        #   in Loop: Header=BB0_8 Depth=1
	vaddss	xmm5, xmm13, xmm7
	vucomiss	xmm14, xmm5
	ja	.LBB0_95
# %bb.69:                               # %L264
                                        #   in Loop: Header=BB0_8 Depth=1
	vsqrtss	xmm3, xmm3, xmm3
	vsqrtss	xmm4, xmm4, xmm4
	vsqrtss	xmm5, xmm5, xmm5
	vmulss	xmm4, xmm4, xmm5
	vmulss	xmm5, xmm7, xmm4
	vucomiss	xmm3, xmm14
	setnp	r8b
	sete	al
	movabs	rcx, offset .LCPI0_5
	vmovss	xmm4, dword ptr [rcx]           # xmm4 = mem[0],zero,zero,zero
	vucomiss	xmm5, xmm4
	jb	.LBB0_81
# %bb.70:                               # %L264
                                        #   in Loop: Header=BB0_8 Depth=1
	vdivss	xmm7, xmm3, xmm5
	vmulss	xmm3, xmm13, xmm7
	and	al, r8b
	movabs	rcx, offset .LCPI0_4
	vmovss	xmm5, dword ptr [rcx]           # xmm5 = mem[0],zero,zero,zero
	vcmpleps	xmm2, xmm7, xmm5
	vcmpleps	xmm6, xmm4, xmm7
	vandps	xmm6, xmm6, xmm2
	vmovd	ecx, xmm6
	vcmpleps	xmm5, xmm3, xmm5
	vcmpleps	xmm4, xmm4, xmm3
	vandps	xmm4, xmm4, xmm5
	vmovd	esi, xmm4
	and	esi, ecx
	or	sil, al
	test	sil, 1
	mov	rsi, qword ptr [rbx + 24]       # 8-byte Reload
	je	.LBB0_81
# %bb.71:                               # %L288
                                        #   in Loop: Header=BB0_8 Depth=1
	vaddss	xmm4, xmm15, xmm0
	movabs	rax, offset .LCPI0_5
	vucomiss	xmm3, dword ptr [rax]
	jb	.LBB0_74
# %bb.72:                               # %L288
                                        #   in Loop: Header=BB0_8 Depth=1
	movabs	rax, offset .LCPI0_4
	vmovss	xmm0, dword ptr [rax]           # xmm0 = mem[0],zero,zero,zero
	vucomiss	xmm0, xmm3
	jb	.LBB0_74
# %bb.73:                               # %L299
                                        #   in Loop: Header=BB0_8 Depth=1
	movabs	rax, offset .LCPI0_1
	vbroadcastss	xmm0, dword ptr [rax]
	vxorps	xmm0, xmm3, xmm0
	vmaxss	xmm0, xmm4, xmm0
	vminss	xmm0, xmm0, xmm3
	vsubss	xmm0, xmm4, xmm0
	vaddss	xmm3, xmm14, xmm0
	jmp	.LBB0_83
.LBB0_81:                               # %L356
                                        #   in Loop: Header=BB0_8 Depth=1
	mov	qword ptr [rbx + 80], rdi
	mov	qword ptr [rbx + 248], rdi
	mov	qword ptr [rbx + 256], r15
	mov	qword ptr [rbx + 264], r12
	mov	qword ptr [rbx + 272], r9
	mov	qword ptr [rbx + 280], 1
	mov	qword ptr [rbx + 104], rsi
	mov	qword ptr [rbx + 96], rdx
	mov	rdi, r10
	lea	rsi, [rbx + 248]
	lea	rcx, [rbx + 48]
	mov	r8, r12
	movabs	rax, offset j__sqrt_cold_2118
	vzeroupper
	call	rax
	vxorps	xmm14, xmm14, xmm14
	mov	rsi, qword ptr [rbx + 24]       # 8-byte Reload
	mov	r10, qword ptr [rbx + 40]       # 8-byte Reload
	vmovaps	xmm3, xmm0
	jmp	.LBB0_83
.LBB0_74:                               # %L323
                                        #   in Loop: Header=BB0_8 Depth=1
	mov	qword ptr [rbx + 104], rsi
	movabs	rax, offset .LCPI0_6
	vmovss	xmm2, dword ptr [rax]           # xmm2 = mem[0],zero,zero,zero
	vmovaps	xmmword ptr [rbx + 144], xmm7   # 16-byte Spill
	vmovaps	xmm0, xmm7
	vmovaps	xmm1, xmm13
	movabs	rax, offset j__exceptional_product_2117
	vmovss	dword ptr [rbx + 56], xmm4      # 4-byte Spill
	vzeroupper
	call	rax
	vmovss	xmm4, dword ptr [rbx + 56]      # 4-byte Reload
                                        # xmm4 = mem[0],zero,zero,zero
	vsubss	xmm2, xmm4, xmm0
	vmovd	eax, xmm2
	vxorps	xmm1, xmm1, xmm1
	vmovaps	xmm3, xmm2
	test	eax, eax
	jns	.LBB0_76
# %bb.75:                               # %L323
                                        #   in Loop: Header=BB0_8 Depth=1
	vxorps	xmm3, xmm3, xmm3
.LBB0_76:                               # %L323
                                        #   in Loop: Header=BB0_8 Depth=1
	vaddss	xmm0, xmm4, xmm0
	vmovd	eax, xmm0
	vxorps	xmm4, xmm4, xmm4
	test	eax, eax
	jns	.LBB0_78
# %bb.77:                               # %L323
                                        #   in Loop: Header=BB0_8 Depth=1
	vmovaps	xmm4, xmm0
.LBB0_78:                               # %L323
                                        #   in Loop: Header=BB0_8 Depth=1
	vcmpordss	xmm5, xmm2, xmm2
	vblendvps	xmm2, xmm2, xmm3, xmm5
	vcmpordss	xmm3, xmm0, xmm0
	vblendvps	xmm0, xmm0, xmm4, xmm3
	vaddss	xmm0, xmm2, xmm0
	and	r13d, 2147483647
	vmovaps	xmm2, xmm0
	cmp	r13d, 2139095040
	mov	r10, qword ptr [rbx + 40]       # 8-byte Reload
	mov	rsi, qword ptr [rbx + 24]       # 8-byte Reload
	vxorps	xmm14, xmm14, xmm14
	vmovaps	xmm3, xmmword ptr [rbx + 144]   # 16-byte Reload
	jne	.LBB0_80
# %bb.79:                               # %L323
                                        #   in Loop: Header=BB0_8 Depth=1
	vxorps	xmm2, xmm2, xmm2
.LBB0_80:                               # %L323
                                        #   in Loop: Header=BB0_8 Depth=1
	vcmpnless	xmm1, xmm1, xmm3
	vblendvps	xmm3, xmm2, xmm0, xmm1
	jmp	.LBB0_83
.LBB0_58:                               #   in Loop: Header=BB0_8 Depth=1
	movabs	rsi, offset .LCPI0_1
	vbroadcastss	ymm4, dword ptr [rsi]
	movabs	rsi, offset .LCPI0_0
	vmovaps	ymm5, ymmword ptr [rsi]
	xor	esi, esi
	test	byte ptr [rbx + 144], 1         # 1-byte Folded Reload
	je	.LBB0_63
	jmp	.LBB0_62
.LBB0_13:                               # %L40
                                        #   in Loop: Header=BB0_8 Depth=1
	test	r13, r13
	je	.LBB0_14
# %bb.15:                               # %L54.lr.ph
                                        #   in Loop: Header=BB0_8 Depth=1
	mov	r11, qword ptr [rcx]
	mov	r8, qword ptr [rcx + 24]
	mov	r15, qword ptr [rax]
	cmp	r13, 8
	jae	.LBB0_17
# %bb.16:                               #   in Loop: Header=BB0_8 Depth=1
	vxorps	xmm1, xmm1, xmm1
	xor	edi, edi
	vxorps	xmm5, xmm5, xmm5
	vxorps	xmm4, xmm4, xmm4
	jmp	.LBB0_25
.LBB0_14:                               #   in Loop: Header=BB0_8 Depth=1
	vxorps	xmm4, xmm4, xmm4
	vxorps	xmm5, xmm5, xmm5
	vxorps	xmm1, xmm1, xmm1
	jmp	.LBB0_42
.LBB0_17:                               # %vector.ph426
                                        #   in Loop: Header=BB0_8 Depth=1
	vmovaps	xmm11, xmm9
	movabs	rax, 9223372036854775792
	lea	rdi, [rax + 8]
	and	rdi, r13
	lea	rax, [rdi - 8]
	mov	rdx, rax
	shr	rdx, 3
	inc	rdx
	mov	r10d, edx
	and	r10d, 3
	cmp	rax, 24
	jae	.LBB0_19
# %bb.18:                               #   in Loop: Header=BB0_8 Depth=1
	movabs	rax, offset .LCPI0_0
	vmovaps	ymm0, ymmword ptr [rax]
	xor	eax, eax
	vmovaps	ymm1, ymm0
	vmovaps	ymm2, ymm0
	jmp	.LBB0_21
.LBB0_19:                               # %vector.ph426.new
                                        #   in Loop: Header=BB0_8 Depth=1
	and	rdx, -4
	mov	rax, r8
	imul	rax, qword ptr [rbx + 32]       # 8-byte Folded Reload
	lea	rsi, [r11 + rax]
	add	rsi, 96
	movabs	rax, offset .LCPI0_0
	vmovaps	ymm0, ymmword ptr [rax]
	xor	eax, eax
	vmovaps	ymm1, ymm0
	vmovaps	ymm2, ymm0
.LBB0_20:                               # %vector.body431
                                        #   Parent Loop BB0_8 Depth=1
                                        # =>  This Inner Loop Header: Depth=2
	vmovups	ymm3, ymmword ptr [rsi + 4*rax - 96]
	vmovups	ymm4, ymmword ptr [rsi + 4*rax - 64]
	vmovups	ymm5, ymmword ptr [rsi + 4*rax - 32]
	vmovups	ymm6, ymmword ptr [rsi + 4*rax]
	vfmadd231ps	ymm0, ymm3, ymm3        # ymm0 = (ymm3 * ymm3) + ymm0
	vmovups	ymm7, ymmword ptr [r15 + 4*rax]
	vmovups	ymm8, ymmword ptr [r15 + 4*rax + 32]
	vmovups	ymm9, ymmword ptr [r15 + 4*rax + 64]
	vmovups	ymm10, ymmword ptr [r15 + 4*rax + 96]
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
	add	rax, 32
	add	rdx, -4
	jne	.LBB0_20
.LBB0_21:                               # %middle.block423.unr-lcssa
                                        #   in Loop: Header=BB0_8 Depth=1
	test	r10, r10
	je	.LBB0_24
# %bb.22:                               # %vector.body431.epil.preheader
                                        #   in Loop: Header=BB0_8 Depth=1
	lea	rcx, [r15 + 4*rax]
	lea	rdx, [r11 + 4*rax]
	mov	rax, r8
	imul	rax, qword ptr [rbx + 32]       # 8-byte Folded Reload
	add	rax, rdx
	shl	r10, 5
	xor	edx, edx
.LBB0_23:                               # %vector.body431.epil
                                        #   Parent Loop BB0_8 Depth=1
                                        # =>  This Inner Loop Header: Depth=2
	vmovups	ymm3, ymmword ptr [rax + rdx]
	vmovups	ymm4, ymmword ptr [rcx + rdx]
	vfmadd231ps	ymm0, ymm3, ymm3        # ymm0 = (ymm3 * ymm3) + ymm0
	vfmadd231ps	ymm1, ymm4, ymm3        # ymm1 = (ymm4 * ymm3) + ymm1
	vfmadd231ps	ymm2, ymm4, ymm4        # ymm2 = (ymm4 * ymm4) + ymm2
	add	rdx, 32
	cmp	r10, rdx
	jne	.LBB0_23
.LBB0_24:                               # %middle.block423
                                        #   in Loop: Header=BB0_8 Depth=1
	vextractf128	xmm3, ymm2, 1
	vaddps	xmm2, xmm2, xmm3
	vpermilpd	xmm3, xmm2, 1           # xmm3 = xmm2[1,0]
	vaddps	xmm2, xmm2, xmm3
	vmovshdup	xmm3, xmm2              # xmm3 = xmm2[1,1,3,3]
	vaddss	xmm4, xmm2, xmm3
	vextractf128	xmm2, ymm1, 1
	vaddps	xmm1, xmm1, xmm2
	vpermilpd	xmm2, xmm1, 1           # xmm2 = xmm1[1,0]
	vaddps	xmm1, xmm1, xmm2
	vmovshdup	xmm2, xmm1              # xmm2 = xmm1[1,1,3,3]
	vaddss	xmm5, xmm1, xmm2
	vextractf128	xmm1, ymm0, 1
	vaddps	xmm0, xmm0, xmm1
	vpermilpd	xmm1, xmm0, 1           # xmm1 = xmm0[1,0]
	vaddps	xmm0, xmm0, xmm1
	vmovshdup	xmm1, xmm0              # xmm1 = xmm0[1,1,3,3]
	vaddss	xmm1, xmm0, xmm1
	cmp	r13, rdi
	mov	r10, qword ptr [rbx + 40]       # 8-byte Reload
	mov	rsi, qword ptr [rbx + 24]       # 8-byte Reload
	vmovaps	xmm9, xmm11
	vxorps	xmm14, xmm14, xmm14
	je	.LBB0_42
.LBB0_25:                               # %scalar.ph424
                                        #   in Loop: Header=BB0_8 Depth=1
	imul	r8, qword ptr [rbx + 32]        # 8-byte Folded Reload
	add	r11, r8
.LBB0_26:                               # %L54
                                        #   Parent Loop BB0_8 Depth=1
                                        # =>  This Inner Loop Header: Depth=2
	vmovss	xmm0, dword ptr [r11 + 4*rdi]   # xmm0 = mem[0],zero,zero,zero
	vmovss	xmm2, dword ptr [r15 + 4*rdi]   # xmm2 = mem[0],zero,zero,zero
	vfmadd231ss	xmm1, xmm0, xmm0        # xmm1 = (xmm0 * xmm0) + xmm1
	vfmadd231ss	xmm5, xmm2, xmm0        # xmm5 = (xmm2 * xmm0) + xmm5
	vfmadd231ss	xmm4, xmm2, xmm2        # xmm4 = (xmm2 * xmm2) + xmm4
	inc	rdi
	cmp	r13, rdi
	jne	.LBB0_26
	jmp	.LBB0_42
	.p2align	4, 0x90
.LBB0_84:
	mov	rax, rcx
	mov	rcx, qword ptr [rbx + 192]      # 8-byte Reload
.LBB0_85:                               # %L374
                                        # =>This Inner Loop Header: Depth=1
	cmp	rcx, qword ptr [rbx + 184]      # 8-byte Folded Reload
	je	.LBB0_86
# %bb.5:                                # %L17thread-pre-split
                                        #   in Loop: Header=BB0_85 Depth=1
	inc	rcx
	mov	rdx, qword ptr [r14 + 8]
	test	rdx, rdx
	jne	.LBB0_7
	jmp	.LBB0_85
.LBB0_1:
	vxorps	xmm9, xmm9, xmm9
	jmp	.LBB0_87
.LBB0_3:
	vxorps	xmm9, xmm9, xmm9
                                        # implicit-def: $rax
                                        # implicit-def: $r15
.LBB0_86:                               # %L385.loopexit
	mov	qword ptr [rbx + 128], r15
	mov	qword ptr [rbx + 136], rax
	mov	rcx, qword ptr [rbx + 168]      # 8-byte Reload
.LBB0_87:                               # %L385
	mov	rax, qword ptr [rbx + 72]
	mov	qword ptr [rcx], rax
	vmovaps	xmm0, xmm9
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
	jge	.LBB0_88
.LBB0_11:                               # %oob
                                        # =>This Inner Loop Header: Depth=1
	xor	qword ptr [rsp], 0
	sub	rsp, 4096
	cmp	rsi, rsp
	jl	.LBB0_11
.LBB0_88:                               # %oob
	mov	rsp, rsi
	mov	qword ptr [rsi], r12
	movabs	rax, offset ijl_bounds_error_ints
	mov	edx, 1
	vzeroupper
	call	rax
.LBB0_43:                               # %oob44
	mov	rsi, rsp
	mov	eax, 16
	sub	rsi, rax
	cmp	rsi, rsp
	jge	.LBB0_89
.LBB0_45:                               # %oob44
                                        # =>This Inner Loop Header: Depth=1
	xor	qword ptr [rsp], 0
	sub	rsp, 4096
	cmp	rsi, rsp
	jl	.LBB0_45
.LBB0_89:                               # %oob44
	mov	rsp, rsi
	mov	qword ptr [rsi], r12
	movabs	rax, offset ijl_bounds_error_ints
	mov	edx, 1
	mov	rdi, r14
	vzeroupper
	call	rax
.LBB0_91:                               # %L145
	mov	qword ptr [rbx + 128], r15
	mov	qword ptr [rbx + 136], r12
	mov	qword ptr [rbx + 96], rdi
	movabs	rax, offset j_throw_boundserror_2119
	lea	rsi, [rbx + 128]
	vzeroupper
	call	rax
.LBB0_92:                               # %L182
	movabs	rax, offset j_throw_complex_domainerror_2115
	movabs	rdi, 140312453360144
	vmovaps	xmm0, xmm1
	vzeroupper
	call	rax
.LBB0_94:                               # %L255
	movabs	rax, offset j_throw_complex_domainerror_2115
	movabs	rdi, 140312453360144
	vmovaps	xmm0, xmm4
	vzeroupper
	call	rax
.LBB0_95:                               # %L262
	movabs	rax, offset j_throw_complex_domainerror_2115
	movabs	rdi, 140312453360144
	vmovaps	xmm0, xmm5
	vzeroupper
	call	rax
.LBB0_93:                               # %L248
	movabs	rax, offset j_throw_complex_domainerror_2115
	movabs	rdi, 140312453360144
	vmovaps	xmm0, xmm3
	vzeroupper
	call	rax
.Lfunc_end0:
	.size	julia_pass_2112, .Lfunc_end0-julia_pass_2112
                                        # -- End function
	.section	".note.GNU-stack","",@progbits
