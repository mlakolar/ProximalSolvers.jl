	.text
	.file	"pass"
	.section	.rodata.cst8,"aM",@progbits,8
	.p2align	3                               # -- Begin function julia_pass_1303
.LCPI0_0:
	.quad	0x8000000000000000              # double -0
.LCPI0_2:
	.quad	0x0350000000000000              # double 1.0020841800044864E-292
.LCPI0_3:
	.quad	0x3fb0000000000000              # double 0.0625
.LCPI0_4:
	.quad	0x7fefffffffffffff              # double 1.7976931348623157E+308
.LCPI0_5:
	.quad	0x0010000000000000              # double 2.2250738585072014E-308
.LCPI0_7:
	.quad	0x3ff0000000000000              # double 1
	.section	.rodata.cst32,"aM",@progbits,32
	.p2align	5
.LCPI0_1:
	.quad	0x0000000000000000              # double 0
	.quad	0x8000000000000000              # double -0
	.quad	0x8000000000000000              # double -0
	.quad	0x8000000000000000              # double -0
	.section	.rodata.cst16,"aM",@progbits,16
	.p2align	4
.LCPI0_6:
	.quad	0x8000000000000000              # double -0
	.quad	0x8000000000000000              # double -0
	.text
	.globl	julia_pass_1303
	.p2align	4, 0x90
	.type	julia_pass_1303,@function
julia_pass_1303:                        # @julia_pass_1303
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
	vxorpd	xmm0, xmm0, xmm0
	vmovapd	ymmword ptr [rbx + 64], ymm0
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
	mov	qword ptr [rbx + 160], rax      # 8-byte Spill
	jle	.LBB0_1
# %bb.2:                                # %L17.preheader
	mov	r10, rsi
	mov	qword ptr [rbx + 152], rcx      # 8-byte Spill
	mov	rsi, qword ptr [rsi + 8]
	test	rsi, rsi
	je	.LBB0_3
# %bb.4:                                # %L17.preheader534
	mov	rdx, qword ptr [rdi]
	vxorpd	xmm10, xmm10, xmm10
	mov	ecx, 1
	movabs	rax, offset .LCPI0_0
	vbroadcastsd	ymm0, qword ptr [rax]
	vmovaps	ymmword ptr [rbx + 320], ymm0   # 32-byte Spill
	movabs	rax, offset .LCPI0_1
	vmovapd	ymm0, ymmword ptr [rax]
	vmovapd	ymmword ptr [rbx + 288], ymm0   # 32-byte Spill
	vxorpd	xmm9, xmm9, xmm9
                                        # implicit-def: $rax
                                        # implicit-def: $r15
	mov	qword ptr [rbx + 40], r10       # 8-byte Spill
	mov	qword ptr [rbx + 48], rdi       # 8-byte Spill
	mov	qword ptr [rbx + 32], rdx       # 8-byte Spill
	test	rsi, rsi
	je	.LBB0_78
	.p2align	4, 0x90
.LBB0_7:                                # %L31.preheader
	mov	qword ptr [rbx + 168], rcx      # 8-byte Spill
	mov	r12d, 1
	xor	r14d, r14d
	mov	qword ptr [rbx + 184], rsi      # 8-byte Spill
	jmp	.LBB0_8
	.p2align	4, 0x90
.LBB0_75:                               # %L356
                                        #   in Loop: Header=BB0_8 Depth=1
	mov	qword ptr [rbx + 88], rdi
	mov	qword ptr [rbx + 192], rdi
	mov	qword ptr [rbx + 200], r15
	mov	qword ptr [rbx + 208], r12
	mov	qword ptr [rbx + 216], r9
	mov	qword ptr [rbx + 224], 1
	mov	rax, qword ptr [rbx + 32]       # 8-byte Reload
	mov	qword ptr [rbx + 104], rax
	mov	qword ptr [rbx + 96], rdx
	mov	rdi, qword ptr [rbx + 48]       # 8-byte Reload
	lea	rsi, [rbx + 192]
	lea	rcx, [rbx + 56]
	mov	r8, r12
	vmovsd	qword ptr [rbx + 24], xmm9      # 8-byte Spill
	movabs	rax, offset j__sqrt_cold_1309
	vzeroupper
	call	rax
	vmovsd	xmm9, qword ptr [rbx + 24]      # 8-byte Reload
                                        # xmm9 = mem[0],zero
	vxorpd	xmm10, xmm10, xmm10
	vmovapd	xmm3, xmm0
.LBB0_76:                               # %L360
                                        #   in Loop: Header=BB0_8 Depth=1
	vaddsd	xmm9, xmm9, xmm3
	lea	rax, [r12 + 1]
	add	r14, 8
	mov	rsi, qword ptr [rbx + 184]      # 8-byte Reload
	cmp	r12, rsi
	mov	r12, rax
	mov	r10, qword ptr [rbx + 40]       # 8-byte Reload
	mov	rdx, qword ptr [rbx + 32]       # 8-byte Reload
	je	.LBB0_77
.LBB0_8:                                # %L31
                                        # =>This Loop Header: Depth=1
                                        #     Child Loop BB0_20 Depth 2
                                        #     Child Loop BB0_25 Depth 2
                                        #     Child Loop BB0_33 Depth 2
                                        #     Child Loop BB0_38 Depth 2
                                        #     Child Loop BB0_55 Depth 2
                                        #     Child Loop BB0_58 Depth 2
	mov	rdi, qword ptr [rdx + 32]
	lea	r9, [r12 - 1]
	cmp	r9, qword ptr [rdi + 8]
	jae	.LBB0_9
# %bb.12:                               # %idxend
                                        #   in Loop: Header=BB0_8 Depth=1
	mov	rcx, qword ptr [rdx]
	mov	rax, qword ptr [rdx + 24]
	mov	rdx, qword ptr [rdi]
	vmovsd	xmm1, qword ptr [rdx + 8*r12 - 8] # xmm1 = mem[0],zero
	vucomisd	xmm1, xmm1
	mov	r13, qword ptr [rax + 8]
	jp	.LBB0_13
# %bb.26:                               # %L83
                                        #   in Loop: Header=BB0_8 Depth=1
	test	r13, r13
	je	.LBB0_27
# %bb.28:                               # %L96.lr.ph
                                        #   in Loop: Header=BB0_8 Depth=1
	mov	r11, qword ptr [rcx]
	mov	r8, qword ptr [rcx + 24]
	mov	rsi, qword ptr [rax]
	cmp	r13, 8
	jae	.LBB0_30
# %bb.29:                               #   in Loop: Header=BB0_8 Depth=1
	vxorpd	xmm4, xmm4, xmm4
	xor	edi, edi
	vxorpd	xmm2, xmm2, xmm2
	jmp	.LBB0_37
	.p2align	4, 0x90
.LBB0_27:                               #   in Loop: Header=BB0_8 Depth=1
	vxorpd	xmm2, xmm2, xmm2
	vxorpd	xmm4, xmm4, xmm4
	jmp	.LBB0_39
	.p2align	4, 0x90
.LBB0_30:                               # %vector.ph415
                                        #   in Loop: Header=BB0_8 Depth=1
	mov	rdi, r13
	movabs	rax, 9223372036854775800
	and	rdi, rax
	lea	rax, [rdi - 8]
	mov	r10, rax
	shr	r10, 3
	inc	r10
	test	rax, rax
	je	.LBB0_31
# %bb.32:                               # %vector.ph415.new
                                        #   in Loop: Header=BB0_8 Depth=1
	mov	rcx, r10
	movabs	rax, 4611686018427387902
	and	rcx, rax
	mov	rax, r8
	imul	rax, r14
	lea	rdx, [r11 + rax]
	add	rdx, 96
	movabs	rax, offset .LCPI0_0
	vbroadcastsd	ymm2, qword ptr [rax]
	movabs	rax, offset .LCPI0_1
	vmovapd	ymm0, ymmword ptr [rax]
	xor	eax, eax
	vmovapd	ymm3, ymm0
	vmovapd	ymm4, ymm2
	.p2align	4, 0x90
.LBB0_33:                               # %vector.body420
                                        #   Parent Loop BB0_8 Depth=1
                                        # =>  This Inner Loop Header: Depth=2
	vmovupd	ymm5, ymmword ptr [rsi + 8*rax]
	vmovupd	ymm6, ymmword ptr [rsi + 8*rax + 32]
	vmovupd	ymm7, ymmword ptr [rsi + 8*rax + 64]
	vmovupd	ymm8, ymmword ptr [rsi + 8*rax + 96]
	vfmadd231pd	ymm0, ymm5, ymmword ptr [rdx + 8*rax - 96] # ymm0 = (ymm5 * mem) + ymm0
	vfmadd231pd	ymm2, ymm6, ymmword ptr [rdx + 8*rax - 64] # ymm2 = (ymm6 * mem) + ymm2
	vfmadd231pd	ymm3, ymm5, ymm5        # ymm3 = (ymm5 * ymm5) + ymm3
	vfmadd231pd	ymm4, ymm6, ymm6        # ymm4 = (ymm6 * ymm6) + ymm4
	vfmadd231pd	ymm0, ymm7, ymmword ptr [rdx + 8*rax - 32] # ymm0 = (ymm7 * mem) + ymm0
	vfmadd231pd	ymm2, ymm8, ymmword ptr [rdx + 8*rax] # ymm2 = (ymm8 * mem) + ymm2
	vfmadd231pd	ymm3, ymm7, ymm7        # ymm3 = (ymm7 * ymm7) + ymm3
	vfmadd231pd	ymm4, ymm8, ymm8        # ymm4 = (ymm8 * ymm8) + ymm4
	add	rax, 16
	add	rcx, -2
	jne	.LBB0_33
# %bb.34:                               # %middle.block412.unr-lcssa
                                        #   in Loop: Header=BB0_8 Depth=1
	test	r10b, 1
	je	.LBB0_36
.LBB0_35:                               # %vector.body420.epil.preheader
                                        #   in Loop: Header=BB0_8 Depth=1
	mov	rcx, r8
	imul	rcx, r9
	add	rcx, rax
	vmovupd	ymm5, ymmword ptr [rsi + 8*rax]
	vmovupd	ymm6, ymmword ptr [rsi + 8*rax + 32]
	vfmadd231pd	ymm0, ymm5, ymmword ptr [r11 + 8*rcx] # ymm0 = (ymm5 * mem) + ymm0
	vfmadd231pd	ymm2, ymm6, ymmword ptr [r11 + 8*rcx + 32] # ymm2 = (ymm6 * mem) + ymm2
	vfmadd231pd	ymm3, ymm5, ymm5        # ymm3 = (ymm5 * ymm5) + ymm3
	vfmadd231pd	ymm4, ymm6, ymm6        # ymm4 = (ymm6 * ymm6) + ymm4
.LBB0_36:                               # %middle.block412
                                        #   in Loop: Header=BB0_8 Depth=1
	vaddpd	ymm0, ymm2, ymm0
	vaddpd	ymm2, ymm4, ymm3
	vextractf128	xmm3, ymm2, 1
	vaddpd	xmm2, xmm2, xmm3
	vpermilpd	xmm3, xmm2, 1           # xmm3 = xmm2[1,0]
	vaddsd	xmm2, xmm2, xmm3
	vextractf128	xmm3, ymm0, 1
	vaddpd	xmm0, xmm0, xmm3
	vpermilpd	xmm3, xmm0, 1           # xmm3 = xmm0[1,0]
	vaddsd	xmm4, xmm0, xmm3
	cmp	r13, rdi
	mov	r10, qword ptr [rbx + 40]       # 8-byte Reload
	je	.LBB0_39
.LBB0_37:                               # %scalar.ph413
                                        #   in Loop: Header=BB0_8 Depth=1
	imul	r8, r14
	add	r11, r8
	.p2align	4, 0x90
.LBB0_38:                               # %L96
                                        #   Parent Loop BB0_8 Depth=1
                                        # =>  This Inner Loop Header: Depth=2
	vmovsd	xmm0, qword ptr [rsi + 8*rdi]   # xmm0 = mem[0],zero
	vfmadd231sd	xmm4, xmm0, qword ptr [r11 + 8*rdi] # xmm4 = (xmm0 * mem) + xmm4
	vfmadd231sd	xmm2, xmm0, xmm0        # xmm2 = (xmm0 * xmm0) + xmm2
	inc	rdi
	cmp	r13, rdi
	jne	.LBB0_38
.LBB0_39:                               # %L124
                                        #   in Loop: Header=BB0_8 Depth=1
	cmp	r9, qword ptr [r10 + 8]
	jae	.LBB0_40
# %bb.83:                               # %idxend46
                                        #   in Loop: Header=BB0_8 Depth=1
	mov	rsi, qword ptr [rbx + 48]       # 8-byte Reload
	mov	rax, qword ptr [rsi]
	mov	rdi, qword ptr [rax]
	mov	r15, qword ptr [rdi + 24]
	cmp	r9, qword ptr [rdi + 32]
	jae	.LBB0_84
# %bb.43:                               # %L148
                                        #   in Loop: Header=BB0_8 Depth=1
	mov	rcx, qword ptr [r10]
	vmovsd	xmm0, qword ptr [rcx + 8*r12 - 8] # xmm0 = mem[0],zero
	imul	r9, r15
	mov	rdx, qword ptr [rax + 24]
	mov	r13, qword ptr [rsi + 8]
	mov	qword ptr [rbx + 56], r13
	vsubsd	xmm3, xmm1, xmm1
	vucomisd	xmm3, xmm3
	jp	.LBB0_75
# %bb.44:                               # %L148
                                        #   in Loop: Header=BB0_8 Depth=1
	mov	r10, qword ptr [rdx + 8]
	vxorps	xmm15, xmm15, xmm15
	vcvtsi2sd	xmm3, xmm15, r10
	movabs	rax, offset .LCPI0_2
	vmulsd	xmm3, xmm3, qword ptr [rax]
	vucomisd	xmm1, xmm3
	jb	.LBB0_75
# %bb.45:                               # %L148
                                        #   in Loop: Header=BB0_8 Depth=1
	vsubsd	xmm5, xmm2, xmm2
	vucomisd	xmm5, xmm5
	jp	.LBB0_75
# %bb.46:                               # %L148
                                        #   in Loop: Header=BB0_8 Depth=1
	vucomisd	xmm2, xmm3
	jb	.LBB0_75
# %bb.47:                               # %L179
                                        #   in Loop: Header=BB0_8 Depth=1
	vucomisd	xmm10, xmm1
	ja	.LBB0_85
# %bb.48:                               # %L184
                                        #   in Loop: Header=BB0_8 Depth=1
	vmovq	xmm8, r13
	vsqrtsd	xmm6, xmm1, xmm1
	vxorpd	xmm3, xmm3, xmm3
	vucomisd	xmm8, xmm6
	jae	.LBB0_76
# %bb.49:                               # %L189
                                        #   in Loop: Header=BB0_8 Depth=1
	vdivsd	xmm15, xmm4, xmm1
	vmulsd	xmm3, xmm15, xmm4
	vsubsd	xmm3, xmm2, xmm3
	movabs	rax, offset .LCPI0_3
	vmulsd	xmm2, xmm2, qword ptr [rax]
	vucomisd	xmm2, xmm3
	vmovsd	qword ptr [rbx + 24], xmm9      # 8-byte Spill
	jbe	.LBB0_59
# %bb.50:                               # %L196
                                        #   in Loop: Header=BB0_8 Depth=1
	test	r10, r10
	je	.LBB0_51
# %bb.52:                               # %L208.lr.ph
                                        #   in Loop: Header=BB0_8 Depth=1
	mov	r11, qword ptr [rdx]
	mov	r8, qword ptr [rdi]
	cmp	r10, 16
	jae	.LBB0_54
# %bb.53:                               #   in Loop: Header=BB0_8 Depth=1
	vxorpd	xmm3, xmm3, xmm3
	xor	esi, esi
	jmp	.LBB0_57
.LBB0_31:                               #   in Loop: Header=BB0_8 Depth=1
	xor	eax, eax
	vmovapd	ymm3, ymmword ptr [rbx + 288]   # 32-byte Reload
	vmovapd	ymm0, ymm3
	vmovapd	ymm4, ymmword ptr [rbx + 320]   # 32-byte Reload
	vmovapd	ymm2, ymm4
	test	r10b, 1
	je	.LBB0_36
	jmp	.LBB0_35
.LBB0_51:                               #   in Loop: Header=BB0_8 Depth=1
	vxorpd	xmm3, xmm3, xmm3
	jmp	.LBB0_60
.LBB0_54:                               # %vector.ph
                                        #   in Loop: Header=BB0_8 Depth=1
	movabs	rax, 9223372036854775800
	lea	rsi, [rax - 8]
	and	rsi, r10
	vbroadcastsd	ymm2, xmm15
	mov	rax, r15
	imul	rax, r14
	add	rax, r8
	add	rax, 96
	movabs	rcx, offset .LCPI0_0
	vbroadcastsd	ymm3, qword ptr [rcx]
	movabs	rcx, offset .LCPI0_1
	vmovapd	ymm4, ymmword ptr [rcx]
	xor	ecx, ecx
	vmovapd	ymm5, ymm3
	vmovapd	ymm9, ymm3
	.p2align	4, 0x90
.LBB0_55:                               # %vector.body
                                        #   Parent Loop BB0_8 Depth=1
                                        # =>  This Inner Loop Header: Depth=2
	vmovupd	ymm10, ymmword ptr [r11 + 8*rcx]
	vmovupd	ymm11, ymmword ptr [r11 + 8*rcx + 32]
	vmovupd	ymm12, ymmword ptr [r11 + 8*rcx + 64]
	vmovupd	ymm13, ymmword ptr [r11 + 8*rcx + 96]
	vmulpd	ymm14, ymm2, ymmword ptr [rax + 8*rcx - 96]
	vsubpd	ymm10, ymm10, ymm14
	vmulpd	ymm14, ymm2, ymmword ptr [rax + 8*rcx - 64]
	vsubpd	ymm11, ymm11, ymm14
	vmulpd	ymm14, ymm2, ymmword ptr [rax + 8*rcx - 32]
	vsubpd	ymm12, ymm12, ymm14
	vmulpd	ymm14, ymm2, ymmword ptr [rax + 8*rcx]
	vsubpd	ymm13, ymm13, ymm14
	vfmadd231pd	ymm4, ymm10, ymm10      # ymm4 = (ymm10 * ymm10) + ymm4
	vfmadd231pd	ymm3, ymm11, ymm11      # ymm3 = (ymm11 * ymm11) + ymm3
	vfmadd231pd	ymm5, ymm12, ymm12      # ymm5 = (ymm12 * ymm12) + ymm5
	vfmadd231pd	ymm9, ymm13, ymm13      # ymm9 = (ymm13 * ymm13) + ymm9
	add	rcx, 16
	cmp	rsi, rcx
	jne	.LBB0_55
# %bb.56:                               # %middle.block
                                        #   in Loop: Header=BB0_8 Depth=1
	vaddpd	ymm2, ymm3, ymm4
	vaddpd	ymm2, ymm5, ymm2
	vaddpd	ymm2, ymm9, ymm2
	vextractf128	xmm3, ymm2, 1
	vaddpd	xmm2, xmm2, xmm3
	vpermilpd	xmm3, xmm2, 1           # xmm3 = xmm2[1,0]
	vaddsd	xmm3, xmm2, xmm3
	cmp	r10, rsi
	vxorpd	xmm10, xmm10, xmm10
	je	.LBB0_59
.LBB0_57:                               # %scalar.ph
                                        #   in Loop: Header=BB0_8 Depth=1
	mov	rax, r15
	imul	rax, r14
	add	r8, rax
	.p2align	4, 0x90
.LBB0_58:                               # %L208
                                        #   Parent Loop BB0_8 Depth=1
                                        # =>  This Inner Loop Header: Depth=2
	vmovsd	xmm2, qword ptr [r11 + 8*rsi]   # xmm2 = mem[0],zero
	vmulsd	xmm4, xmm15, qword ptr [r8 + 8*rsi]
	vsubsd	xmm2, xmm2, xmm4
	vfmadd231sd	xmm3, xmm2, xmm2        # xmm3 = (xmm2 * xmm2) + xmm3
	inc	rsi
	cmp	r10, rsi
	jne	.LBB0_58
.LBB0_59:                               # %L245
                                        #   in Loop: Header=BB0_8 Depth=1
	vucomisd	xmm10, xmm3
	ja	.LBB0_86
.LBB0_60:                               # %L250
                                        #   in Loop: Header=BB0_8 Depth=1
	vsubsd	xmm4, xmm6, xmm8
	vucomisd	xmm10, xmm4
	ja	.LBB0_87
# %bb.61:                               # %L257
                                        #   in Loop: Header=BB0_8 Depth=1
	vaddsd	xmm5, xmm8, xmm6
	vucomisd	xmm10, xmm5
	ja	.LBB0_88
# %bb.62:                               # %L264
                                        #   in Loop: Header=BB0_8 Depth=1
	vsqrtsd	xmm2, xmm3, xmm3
	vsqrtsd	xmm3, xmm4, xmm4
	vsqrtsd	xmm4, xmm5, xmm5
	vmulsd	xmm3, xmm3, xmm4
	vmulsd	xmm4, xmm6, xmm3
	vucomisd	xmm2, xmm10
	setnp	cl
	sete	al
	movabs	rsi, offset .LCPI0_5
	vmovsd	xmm3, qword ptr [rsi]           # xmm3 = mem[0],zero
	vucomisd	xmm4, xmm3
	jb	.LBB0_74
# %bb.63:                               # %L264
                                        #   in Loop: Header=BB0_8 Depth=1
	vdivsd	xmm7, xmm2, xmm4
	vmulsd	xmm2, xmm8, xmm7
	and	al, cl
	movabs	rcx, offset .LCPI0_4
	vmovsd	xmm4, qword ptr [rcx]           # xmm4 = mem[0],zero
	vcmplepd	xmm5, xmm7, xmm4
	vcmplepd	xmm6, xmm3, xmm7
	vandpd	xmm5, xmm6, xmm5
	vcmplepd	xmm4, xmm2, xmm4
	vcmplepd	xmm3, xmm3, xmm2
	vandpd	xmm3, xmm3, xmm4
	vmovd	ecx, xmm5
	vmovd	esi, xmm3
	and	esi, ecx
	or	sil, al
	test	sil, 1
	je	.LBB0_74
# %bb.64:                               # %L288
                                        #   in Loop: Header=BB0_8 Depth=1
	vaddsd	xmm3, xmm15, xmm0
	movabs	rax, offset .LCPI0_5
	vucomisd	xmm2, qword ptr [rax]
	jb	.LBB0_67
# %bb.65:                               # %L288
                                        #   in Loop: Header=BB0_8 Depth=1
	movabs	rax, offset .LCPI0_4
	vmovsd	xmm0, qword ptr [rax]           # xmm0 = mem[0],zero
	vucomisd	xmm0, xmm2
	jb	.LBB0_67
# %bb.66:                               # %L299
                                        #   in Loop: Header=BB0_8 Depth=1
	movabs	rax, offset .LCPI0_6
	vxorpd	xmm0, xmm2, xmmword ptr [rax]
	vmaxsd	xmm0, xmm3, xmm0
	vminsd	xmm0, xmm0, xmm2
	vsubsd	xmm0, xmm3, xmm0
	vaddsd	xmm3, xmm10, xmm0
	vmovsd	xmm9, qword ptr [rbx + 24]      # 8-byte Reload
                                        # xmm9 = mem[0],zero
	jmp	.LBB0_76
.LBB0_74:                               # %L354
                                        #   in Loop: Header=BB0_8 Depth=1
	mov	qword ptr [rbx + 80], rdi
	mov	qword ptr [rbx + 232], rdi
	mov	qword ptr [rbx + 240], r15
	mov	qword ptr [rbx + 248], r12
	mov	qword ptr [rbx + 256], r9
	mov	qword ptr [rbx + 264], 1
	mov	rax, qword ptr [rbx + 32]       # 8-byte Reload
	mov	qword ptr [rbx + 104], rax
	mov	qword ptr [rbx + 96], rdx
	mov	rdi, qword ptr [rbx + 48]       # 8-byte Reload
	lea	rsi, [rbx + 232]
	lea	rcx, [rbx + 56]
	mov	r8, r12
	movabs	rax, offset j__sqrt_cold_1309
	vzeroupper
	call	rax
	vxorpd	xmm10, xmm10, xmm10
	vmovapd	xmm3, xmm0
	vmovsd	xmm9, qword ptr [rbx + 24]      # 8-byte Reload
                                        # xmm9 = mem[0],zero
	jmp	.LBB0_76
.LBB0_67:                               # %L323
                                        #   in Loop: Header=BB0_8 Depth=1
	mov	rax, qword ptr [rbx + 32]       # 8-byte Reload
	mov	qword ptr [rbx + 104], rax
	movabs	rax, offset .LCPI0_7
	vmovsd	xmm2, qword ptr [rax]           # xmm2 = mem[0],zero
	vmovapd	xmmword ptr [rbx + 272], xmm7   # 16-byte Spill
	vmovapd	xmm0, xmm7
	vmovapd	xmm1, xmm8
	movabs	rax, offset j__exceptional_product_1308
	vmovsd	qword ptr [rbx + 176], xmm3     # 8-byte Spill
	vzeroupper
	call	rax
	vmovsd	xmm4, qword ptr [rbx + 176]     # 8-byte Reload
                                        # xmm4 = mem[0],zero
	vsubsd	xmm2, xmm4, xmm0
	vmovq	rax, xmm2
	vxorpd	xmm1, xmm1, xmm1
	vmovapd	xmm3, xmm2
	test	rax, rax
	jns	.LBB0_69
# %bb.68:                               # %L323
                                        #   in Loop: Header=BB0_8 Depth=1
	vxorpd	xmm3, xmm3, xmm3
.LBB0_69:                               # %L323
                                        #   in Loop: Header=BB0_8 Depth=1
	vaddsd	xmm0, xmm4, xmm0
	vmovq	rax, xmm0
	vxorpd	xmm4, xmm4, xmm4
	test	rax, rax
	jns	.LBB0_71
# %bb.70:                               # %L323
                                        #   in Loop: Header=BB0_8 Depth=1
	vmovapd	xmm4, xmm0
.LBB0_71:                               # %L323
                                        #   in Loop: Header=BB0_8 Depth=1
	vcmpordsd	xmm5, xmm2, xmm2
	vblendvpd	xmm2, xmm2, xmm3, xmm5
	vcmpordsd	xmm3, xmm0, xmm0
	vblendvpd	xmm0, xmm0, xmm4, xmm3
	vaddsd	xmm0, xmm2, xmm0
	mov	al, 63
	bzhi	rax, r13, rax
	vmovapd	xmm2, xmm0
	movabs	rcx, 9218868437227405312
	cmp	rax, rcx
	vxorpd	xmm10, xmm10, xmm10
	vmovsd	xmm9, qword ptr [rbx + 24]      # 8-byte Reload
                                        # xmm9 = mem[0],zero
	jne	.LBB0_73
# %bb.72:                               # %L323
                                        #   in Loop: Header=BB0_8 Depth=1
	vxorpd	xmm2, xmm2, xmm2
.LBB0_73:                               # %L323
                                        #   in Loop: Header=BB0_8 Depth=1
	vcmpnlesd	xmm1, xmm1, qword ptr [rbx + 272] # 16-byte Folded Reload
	vblendvpd	xmm3, xmm2, xmm0, xmm1
	jmp	.LBB0_76
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
	vxorpd	xmm1, xmm1, xmm1
	xor	edi, edi
	vxorpd	xmm4, xmm4, xmm4
	vxorpd	xmm2, xmm2, xmm2
	jmp	.LBB0_24
.LBB0_14:                               #   in Loop: Header=BB0_8 Depth=1
	vxorpd	xmm2, xmm2, xmm2
	vxorpd	xmm4, xmm4, xmm4
	vxorpd	xmm1, xmm1, xmm1
	jmp	.LBB0_39
.LBB0_17:                               # %vector.ph438
                                        #   in Loop: Header=BB0_8 Depth=1
	vmovapd	xmm14, xmm9
	mov	rdi, r13
	movabs	rax, 9223372036854775800
	and	rdi, rax
	lea	rax, [rdi - 8]
	mov	r10, rax
	shr	r10, 3
	inc	r10
	test	rax, rax
	je	.LBB0_18
# %bb.19:                               # %vector.ph438.new
                                        #   in Loop: Header=BB0_8 Depth=1
	mov	rdx, r10
	movabs	rax, 4611686018427387902
	and	rdx, rax
	mov	rax, r8
	imul	rax, r14
	lea	rsi, [r11 + rax]
	add	rsi, 96
	movabs	rax, offset .LCPI0_0
	vbroadcastsd	ymm0, qword ptr [rax]
	movabs	rax, offset .LCPI0_1
	vmovapd	ymm1, ymmword ptr [rax]
	xor	eax, eax
	vmovapd	ymm2, ymm1
	vmovapd	ymm3, ymm0
	vmovapd	ymm4, ymm1
	vmovapd	ymm5, ymm0
.LBB0_20:                               # %vector.body443
                                        #   Parent Loop BB0_8 Depth=1
                                        # =>  This Inner Loop Header: Depth=2
	vmovupd	ymm6, ymmword ptr [rsi + 8*rax - 96]
	vmovupd	ymm7, ymmword ptr [rsi + 8*rax - 64]
	vmovupd	ymm8, ymmword ptr [rsi + 8*rax - 32]
	vmovupd	ymm9, ymmword ptr [rsi + 8*rax]
	vfmadd231pd	ymm1, ymm6, ymm6        # ymm1 = (ymm6 * ymm6) + ymm1
	vfmadd231pd	ymm0, ymm7, ymm7        # ymm0 = (ymm7 * ymm7) + ymm0
	vmovupd	ymm10, ymmword ptr [r15 + 8*rax]
	vmovupd	ymm11, ymmword ptr [r15 + 8*rax + 32]
	vmovupd	ymm12, ymmword ptr [r15 + 8*rax + 64]
	vmovupd	ymm13, ymmword ptr [r15 + 8*rax + 96]
	vfmadd231pd	ymm2, ymm10, ymm6       # ymm2 = (ymm10 * ymm6) + ymm2
	vfmadd231pd	ymm3, ymm11, ymm7       # ymm3 = (ymm11 * ymm7) + ymm3
	vfmadd231pd	ymm4, ymm10, ymm10      # ymm4 = (ymm10 * ymm10) + ymm4
	vfmadd231pd	ymm5, ymm11, ymm11      # ymm5 = (ymm11 * ymm11) + ymm5
	vfmadd231pd	ymm1, ymm8, ymm8        # ymm1 = (ymm8 * ymm8) + ymm1
	vfmadd231pd	ymm0, ymm9, ymm9        # ymm0 = (ymm9 * ymm9) + ymm0
	vfmadd231pd	ymm2, ymm12, ymm8       # ymm2 = (ymm12 * ymm8) + ymm2
	vfmadd231pd	ymm3, ymm13, ymm9       # ymm3 = (ymm13 * ymm9) + ymm3
	vfmadd231pd	ymm4, ymm12, ymm12      # ymm4 = (ymm12 * ymm12) + ymm4
	vfmadd231pd	ymm5, ymm13, ymm13      # ymm5 = (ymm13 * ymm13) + ymm5
	add	rax, 16
	add	rdx, -2
	jne	.LBB0_20
	jmp	.LBB0_21
.LBB0_18:                               #   in Loop: Header=BB0_8 Depth=1
	movabs	rax, offset .LCPI0_0
	vbroadcastsd	ymm0, qword ptr [rax]
	movabs	rax, offset .LCPI0_1
	vmovapd	ymm1, ymmword ptr [rax]
	xor	eax, eax
	vmovapd	ymm2, ymm1
	vmovapd	ymm3, ymm0
	vmovapd	ymm4, ymm1
	vmovapd	ymm5, ymm0
.LBB0_21:                               # %middle.block435.unr-lcssa
                                        #   in Loop: Header=BB0_8 Depth=1
	test	r10b, 1
	je	.LBB0_23
# %bb.22:                               # %vector.body443.epil.preheader
                                        #   in Loop: Header=BB0_8 Depth=1
	mov	rcx, r8
	imul	rcx, r9
	add	rcx, rax
	vmovupd	ymm6, ymmword ptr [r11 + 8*rcx]
	vmovupd	ymm7, ymmword ptr [r11 + 8*rcx + 32]
	vmovupd	ymm8, ymmword ptr [r15 + 8*rax]
	vmovupd	ymm9, ymmword ptr [r15 + 8*rax + 32]
	vfmadd231pd	ymm1, ymm6, ymm6        # ymm1 = (ymm6 * ymm6) + ymm1
	vfmadd231pd	ymm0, ymm7, ymm7        # ymm0 = (ymm7 * ymm7) + ymm0
	vfmadd231pd	ymm2, ymm8, ymm6        # ymm2 = (ymm8 * ymm6) + ymm2
	vfmadd231pd	ymm3, ymm9, ymm7        # ymm3 = (ymm9 * ymm7) + ymm3
	vfmadd231pd	ymm4, ymm8, ymm8        # ymm4 = (ymm8 * ymm8) + ymm4
	vfmadd231pd	ymm5, ymm9, ymm9        # ymm5 = (ymm9 * ymm9) + ymm5
.LBB0_23:                               # %middle.block435
                                        #   in Loop: Header=BB0_8 Depth=1
	vaddpd	ymm0, ymm0, ymm1
	vaddpd	ymm1, ymm3, ymm2
	vaddpd	ymm2, ymm5, ymm4
	vextractf128	xmm3, ymm2, 1
	vaddpd	xmm2, xmm2, xmm3
	vpermilpd	xmm3, xmm2, 1           # xmm3 = xmm2[1,0]
	vaddsd	xmm2, xmm2, xmm3
	vextractf128	xmm3, ymm1, 1
	vaddpd	xmm1, xmm1, xmm3
	vpermilpd	xmm3, xmm1, 1           # xmm3 = xmm1[1,0]
	vaddsd	xmm4, xmm1, xmm3
	vextractf128	xmm1, ymm0, 1
	vaddpd	xmm0, xmm0, xmm1
	vpermilpd	xmm1, xmm0, 1           # xmm1 = xmm0[1,0]
	vaddsd	xmm1, xmm0, xmm1
	cmp	r13, rdi
	mov	r10, qword ptr [rbx + 40]       # 8-byte Reload
	vxorpd	xmm10, xmm10, xmm10
	vmovapd	xmm9, xmm14
	je	.LBB0_39
.LBB0_24:                               # %scalar.ph436
                                        #   in Loop: Header=BB0_8 Depth=1
	imul	r8, r14
	add	r11, r8
.LBB0_25:                               # %L54
                                        #   Parent Loop BB0_8 Depth=1
                                        # =>  This Inner Loop Header: Depth=2
	vmovsd	xmm0, qword ptr [r11 + 8*rdi]   # xmm0 = mem[0],zero
	vmovsd	xmm3, qword ptr [r15 + 8*rdi]   # xmm3 = mem[0],zero
	vfmadd231sd	xmm1, xmm0, xmm0        # xmm1 = (xmm0 * xmm0) + xmm1
	vfmadd231sd	xmm4, xmm3, xmm0        # xmm4 = (xmm3 * xmm0) + xmm4
	vfmadd231sd	xmm2, xmm3, xmm3        # xmm2 = (xmm3 * xmm3) + xmm2
	inc	rdi
	cmp	r13, rdi
	jne	.LBB0_25
	jmp	.LBB0_39
	.p2align	4, 0x90
.LBB0_77:
	mov	rax, rsi
	mov	rcx, qword ptr [rbx + 168]      # 8-byte Reload
.LBB0_78:                               # %L372
                                        # =>This Inner Loop Header: Depth=1
	cmp	rcx, qword ptr [rbx + 160]      # 8-byte Folded Reload
	je	.LBB0_79
# %bb.5:                                # %L17thread-pre-split
                                        #   in Loop: Header=BB0_78 Depth=1
	inc	rcx
	mov	rsi, qword ptr [r10 + 8]
	test	rsi, rsi
	jne	.LBB0_7
	jmp	.LBB0_78
.LBB0_1:
	vxorpd	xmm9, xmm9, xmm9
	jmp	.LBB0_80
.LBB0_3:
	vxorpd	xmm9, xmm9, xmm9
                                        # implicit-def: $rax
                                        # implicit-def: $r15
.LBB0_79:                               # %L383.loopexit
	mov	qword ptr [rbx + 136], r15
	mov	qword ptr [rbx + 144], rax
	mov	rcx, qword ptr [rbx + 152]      # 8-byte Reload
.LBB0_80:                               # %L383
	mov	rax, qword ptr [rbx + 72]
	mov	qword ptr [rcx], rax
	vmovapd	xmm0, xmm9
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
	jge	.LBB0_81
.LBB0_11:                               # %oob
                                        # =>This Inner Loop Header: Depth=1
	xor	qword ptr [rsp], 0
	sub	rsp, 4096
	cmp	rsi, rsp
	jl	.LBB0_11
.LBB0_81:                               # %oob
	mov	rsp, rsi
	mov	qword ptr [rsi], r12
	movabs	rax, offset ijl_bounds_error_ints
	mov	edx, 1
	vzeroupper
	call	rax
.LBB0_40:                               # %oob44
	mov	rsi, rsp
	mov	eax, 16
	sub	rsi, rax
	cmp	rsi, rsp
	jge	.LBB0_82
.LBB0_42:                               # %oob44
                                        # =>This Inner Loop Header: Depth=1
	xor	qword ptr [rsp], 0
	sub	rsp, 4096
	cmp	rsi, rsp
	jl	.LBB0_42
.LBB0_82:                               # %oob44
	mov	rsp, rsi
	mov	qword ptr [rsi], r12
	movabs	rax, offset ijl_bounds_error_ints
	mov	edx, 1
	mov	rdi, r10
	vzeroupper
	call	rax
.LBB0_84:                               # %L145
	mov	qword ptr [rbx + 136], r15
	mov	qword ptr [rbx + 144], r12
	mov	qword ptr [rbx + 96], rdi
	movabs	rax, offset j_throw_boundserror_1310
	lea	rsi, [rbx + 136]
	vzeroupper
	call	rax
.LBB0_85:                               # %L182
	movabs	rax, offset j_throw_complex_domainerror_1306
	movabs	rdi, 140312453360144
	vmovapd	xmm0, xmm1
	vzeroupper
	call	rax
.LBB0_87:                               # %L255
	movabs	rax, offset j_throw_complex_domainerror_1306
	movabs	rdi, 140312453360144
	vmovapd	xmm0, xmm4
	vzeroupper
	call	rax
.LBB0_88:                               # %L262
	movabs	rax, offset j_throw_complex_domainerror_1306
	movabs	rdi, 140312453360144
	vmovapd	xmm0, xmm5
	vzeroupper
	call	rax
.LBB0_86:                               # %L248
	movabs	rax, offset j_throw_complex_domainerror_1306
	movabs	rdi, 140312453360144
	vmovapd	xmm0, xmm3
	vzeroupper
	call	rax
.Lfunc_end0:
	.size	julia_pass_1303, .Lfunc_end0-julia_pass_1303
                                        # -- End function
	.section	".note.GNU-stack","",@progbits
