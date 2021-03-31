; NOTE: Assertions have been autogenerated by utils/update_test_checks.py
; RUN: opt < %s -indvars -S -indvars-predicate-loops=0 | FileCheck %s

; Make sure that indvars can perform LFTR without a canonical IV.

target datalayout = "e-p:64:64:64-i1:8:8-i8:8:8-i16:16:16-i32:32:32-i64:64:64-f32:32:32-f64:64:64-v64:64:64-v128:128:128-a0:0:64-s0:64:64-f80:128:128-n8:16:32:64"

; Perform LFTR using the original pointer-type IV.

declare void @use(double %x)

;  for(char* p = base; p < base + n; ++p) {
;    *p = p-base;
;  }
define void @ptriv(i8* %base, i32 %n) nounwind {
; CHECK-LABEL: @ptriv(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    [[IDX_EXT:%.*]] = sext i32 [[N:%.*]] to i64
; CHECK-NEXT:    [[ADD_PTR:%.*]] = getelementptr inbounds i8, i8* [[BASE:%.*]], i64 [[IDX_EXT]]
; CHECK-NEXT:    [[CMP1:%.*]] = icmp ult i8* [[BASE]], [[ADD_PTR]]
; CHECK-NEXT:    br i1 [[CMP1]], label [[FOR_BODY_PREHEADER:%.*]], label [[FOR_END:%.*]]
; CHECK:       for.body.preheader:
; CHECK-NEXT:    br label [[FOR_BODY:%.*]]
; CHECK:       for.body:
; CHECK-NEXT:    [[P_02:%.*]] = phi i8* [ [[INCDEC_PTR:%.*]], [[FOR_BODY]] ], [ [[BASE]], [[FOR_BODY_PREHEADER]] ]
; CHECK-NEXT:    [[SUB_PTR_LHS_CAST:%.*]] = ptrtoint i8* [[P_02]] to i64
; CHECK-NEXT:    [[SUB_PTR_RHS_CAST:%.*]] = ptrtoint i8* [[BASE]] to i64
; CHECK-NEXT:    [[SUB_PTR_SUB:%.*]] = sub i64 [[SUB_PTR_LHS_CAST]], [[SUB_PTR_RHS_CAST]]
; CHECK-NEXT:    [[CONV:%.*]] = trunc i64 [[SUB_PTR_SUB]] to i8
; CHECK-NEXT:    store i8 [[CONV]], i8* [[P_02]]
; CHECK-NEXT:    [[INCDEC_PTR]] = getelementptr inbounds i8, i8* [[P_02]], i32 1
; CHECK-NEXT:    [[EXITCOND:%.*]] = icmp ne i8* [[INCDEC_PTR]], [[ADD_PTR]]
; CHECK-NEXT:    br i1 [[EXITCOND]], label [[FOR_BODY]], label [[FOR_END_LOOPEXIT:%.*]]
; CHECK:       for.end.loopexit:
; CHECK-NEXT:    br label [[FOR_END]]
; CHECK:       for.end:
; CHECK-NEXT:    ret void
;
entry:
  %idx.ext = sext i32 %n to i64
  %add.ptr = getelementptr inbounds i8, i8* %base, i64 %idx.ext
  %cmp1 = icmp ult i8* %base, %add.ptr
  br i1 %cmp1, label %for.body, label %for.end

for.body:
  %p.02 = phi i8* [ %base, %entry ], [ %incdec.ptr, %for.body ]
  ; cruft to make the IV useful
  %sub.ptr.lhs.cast = ptrtoint i8* %p.02 to i64
  %sub.ptr.rhs.cast = ptrtoint i8* %base to i64
  %sub.ptr.sub = sub i64 %sub.ptr.lhs.cast, %sub.ptr.rhs.cast
  %conv = trunc i64 %sub.ptr.sub to i8
  store i8 %conv, i8* %p.02
  %incdec.ptr = getelementptr inbounds i8, i8* %p.02, i32 1
  %cmp = icmp ult i8* %incdec.ptr, %add.ptr
  br i1 %cmp, label %for.body, label %for.end

for.end:
  ret void
}

; This test checks that SCEVExpander can handle an outer loop that has been
; simplified, and as a result the inner loop's exit test will be rewritten.
define void @expandOuterRecurrence(i32 %arg) nounwind {
; CHECK-LABEL: @expandOuterRecurrence(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    [[SUB1:%.*]] = sub nsw i32 [[ARG:%.*]], 1
; CHECK-NEXT:    [[CMP1:%.*]] = icmp slt i32 0, [[SUB1]]
; CHECK-NEXT:    br i1 [[CMP1]], label [[OUTER_PREHEADER:%.*]], label [[EXIT:%.*]]
; CHECK:       outer.preheader:
; CHECK-NEXT:    [[TMP0:%.*]] = add i32 [[ARG]], -1
; CHECK-NEXT:    br label [[OUTER:%.*]]
; CHECK:       outer:
; CHECK-NEXT:    [[INDVARS_IV:%.*]] = phi i32 [ [[TMP0]], [[OUTER_PREHEADER]] ], [ [[INDVARS_IV_NEXT:%.*]], [[OUTER_INC:%.*]] ]
; CHECK-NEXT:    [[I:%.*]] = phi i32 [ [[I_INC:%.*]], [[OUTER_INC]] ], [ 0, [[OUTER_PREHEADER]] ]
; CHECK-NEXT:    [[SUB2:%.*]] = sub nsw i32 [[ARG]], [[I]]
; CHECK-NEXT:    [[SUB3:%.*]] = sub nsw i32 [[SUB2]], 1
; CHECK-NEXT:    [[CMP2:%.*]] = icmp slt i32 0, [[SUB3]]
; CHECK-NEXT:    br i1 [[CMP2]], label [[INNER_PH:%.*]], label [[OUTER_INC]]
; CHECK:       inner.ph:
; CHECK-NEXT:    br label [[INNER:%.*]]
; CHECK:       inner:
; CHECK-NEXT:    [[J:%.*]] = phi i32 [ 0, [[INNER_PH]] ], [ [[J_INC:%.*]], [[INNER]] ]
; CHECK-NEXT:    [[J_INC]] = add nuw nsw i32 [[J]], 1
; CHECK-NEXT:    [[EXITCOND:%.*]] = icmp ne i32 [[J_INC]], [[INDVARS_IV]]
; CHECK-NEXT:    br i1 [[EXITCOND]], label [[INNER]], label [[OUTER_INC_LOOPEXIT:%.*]]
; CHECK:       outer.inc.loopexit:
; CHECK-NEXT:    br label [[OUTER_INC]]
; CHECK:       outer.inc:
; CHECK-NEXT:    [[I_INC]] = add nuw nsw i32 [[I]], 1
; CHECK-NEXT:    [[INDVARS_IV_NEXT]] = add i32 [[INDVARS_IV]], -1
; CHECK-NEXT:    [[EXITCOND1:%.*]] = icmp ne i32 [[I_INC]], [[TMP0]]
; CHECK-NEXT:    br i1 [[EXITCOND1]], label [[OUTER]], label [[EXIT_LOOPEXIT:%.*]]
; CHECK:       exit.loopexit:
; CHECK-NEXT:    br label [[EXIT]]
; CHECK:       exit:
; CHECK-NEXT:    ret void
;
entry:
  %sub1 = sub nsw i32 %arg, 1
  %cmp1 = icmp slt i32 0, %sub1
  br i1 %cmp1, label %outer, label %exit

outer:
  %i = phi i32 [ 0, %entry ], [ %i.inc, %outer.inc ]
  %sub2 = sub nsw i32 %arg, %i
  %sub3 = sub nsw i32 %sub2, 1
  %cmp2 = icmp slt i32 0, %sub3
  br i1 %cmp2, label %inner.ph, label %outer.inc

inner.ph:
  br label %inner

inner:
  %j = phi i32 [ 0, %inner.ph ], [ %j.inc, %inner ]
  %j.inc = add nsw i32 %j, 1
  %cmp3 = icmp slt i32 %j.inc, %sub3
  br i1 %cmp3, label %inner, label %outer.inc

outer.inc:
  %i.inc = add nsw i32 %i, 1
  %cmp4 = icmp slt i32 %i.inc, %sub1
  br i1 %cmp4, label %outer, label %exit

exit:
  ret void
}

; Force SCEVExpander to look for an existing well-formed phi.
; Perform LFTR without generating extra preheader code.
define void @guardedloop([0 x double]* %matrix, [0 x double]* %vector,
;
; CHECK-LABEL: @guardedloop(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    [[CMP:%.*]] = icmp slt i32 1, [[IROW:%.*]]
; CHECK-NEXT:    br i1 [[CMP]], label [[LOOP_PREHEADER:%.*]], label [[RETURN:%.*]]
; CHECK:       loop.preheader:
; CHECK-NEXT:    [[TMP0:%.*]] = sext i32 [[ILEAD:%.*]] to i64
; CHECK-NEXT:    [[WIDE_TRIP_COUNT:%.*]] = zext i32 [[IROW]] to i64
; CHECK-NEXT:    br label [[LOOP:%.*]]
; CHECK:       loop:
; CHECK-NEXT:    [[INDVARS_IV2:%.*]] = phi i64 [ 0, [[LOOP_PREHEADER]] ], [ [[INDVARS_IV_NEXT3:%.*]], [[LOOP]] ]
; CHECK-NEXT:    [[INDVARS_IV:%.*]] = phi i64 [ 0, [[LOOP_PREHEADER]] ], [ [[INDVARS_IV_NEXT:%.*]], [[LOOP]] ]
; CHECK-NEXT:    [[TMP1:%.*]] = add nsw i64 [[INDVARS_IV]], [[INDVARS_IV2]]
; CHECK-NEXT:    [[MATRIXP:%.*]] = getelementptr inbounds [0 x double], [0 x double]* [[MATRIX:%.*]], i32 0, i64 [[TMP1]]
; CHECK-NEXT:    [[V1:%.*]] = load double, double* [[MATRIXP]]
; CHECK-NEXT:    call void @use(double [[V1]])
; CHECK-NEXT:    [[VECTORP:%.*]] = getelementptr inbounds [0 x double], [0 x double]* [[VECTOR:%.*]], i32 0, i64 [[INDVARS_IV2]]
; CHECK-NEXT:    [[V2:%.*]] = load double, double* [[VECTORP]]
; CHECK-NEXT:    call void @use(double [[V2]])
; CHECK-NEXT:    [[INDVARS_IV_NEXT]] = add nsw i64 [[INDVARS_IV]], [[TMP0]]
; CHECK-NEXT:    [[INDVARS_IV_NEXT3]] = add nuw nsw i64 [[INDVARS_IV2]], 1
; CHECK-NEXT:    [[EXITCOND:%.*]] = icmp ne i64 [[INDVARS_IV_NEXT3]], [[WIDE_TRIP_COUNT]]
; CHECK-NEXT:    br i1 [[EXITCOND]], label [[LOOP]], label [[RETURN_LOOPEXIT:%.*]]
; CHECK:       return.loopexit:
; CHECK-NEXT:    br label [[RETURN]]
; CHECK:       return:
; CHECK-NEXT:    ret void
;
  i32 %irow, i32 %ilead) nounwind {
entry:
  %cmp = icmp slt i32 1, %irow
  br i1 %cmp, label %loop, label %return

loop:
  %rowidx = phi i32 [ 0, %entry ], [ %row.inc, %loop ]
  %i = phi i32 [ 0, %entry ], [ %i.inc, %loop ]
  %diagidx = add nsw i32 %rowidx, %i
  %diagidxw = sext i32 %diagidx to i64
  %matrixp = getelementptr inbounds [0 x double], [0 x double]* %matrix, i32 0, i64 %diagidxw
  %v1 = load double, double* %matrixp
  call void @use(double %v1)
  %iw = sext i32 %i to i64
  %vectorp = getelementptr inbounds [0 x double], [0 x double]* %vector, i32 0, i64 %iw
  %v2 = load double, double* %vectorp
  call void @use(double %v2)
  %row.inc = add nsw i32 %rowidx, %ilead
  %i.inc = add nsw i32 %i, 1
  %cmp196 = icmp slt i32 %i.inc, %irow
  br i1 %cmp196, label %loop, label %return

return:
  ret void
}

; Avoid generating extra code to materialize a trip count. Skip LFTR.
define void @unguardedloop([0 x double]* %matrix, [0 x double]* %vector,
;
; CHECK-LABEL: @unguardedloop(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    [[TMP0:%.*]] = icmp sgt i32 [[IROW:%.*]], 1
; CHECK-NEXT:    [[SMAX:%.*]] = select i1 [[TMP0]], i32 [[IROW]], i32 1
; CHECK-NEXT:    [[WIDE_TRIP_COUNT:%.*]] = zext i32 [[SMAX]] to i64
; CHECK-NEXT:    br label [[LOOP:%.*]]
; CHECK:       loop:
; CHECK-NEXT:    [[INDVARS_IV2:%.*]] = phi i64 [ [[INDVARS_IV_NEXT3:%.*]], [[LOOP]] ], [ 0, [[ENTRY:%.*]] ]
; CHECK-NEXT:    [[INDVARS_IV_NEXT3]] = add nuw nsw i64 [[INDVARS_IV2]], 1
; CHECK-NEXT:    [[EXITCOND:%.*]] = icmp ne i64 [[INDVARS_IV_NEXT3]], [[WIDE_TRIP_COUNT]]
; CHECK-NEXT:    br i1 [[EXITCOND]], label [[LOOP]], label [[RETURN:%.*]]
; CHECK:       return:
; CHECK-NEXT:    ret void
;
  i32 %irow, i32 %ilead) nounwind {
entry:
  br label %loop

loop:
  %rowidx = phi i32 [ 0, %entry ], [ %row.inc, %loop ]
  %i = phi i32 [ 0, %entry ], [ %i.inc, %loop ]
  %diagidx = add nsw i32 %rowidx, %i
  %diagidxw = sext i32 %diagidx to i64
  %matrixp = getelementptr inbounds [0 x double], [0 x double]* %matrix, i32 0, i64 %diagidxw
  %v1 = load double, double* %matrixp
  %iw = sext i32 %i to i64
  %vectorp = getelementptr inbounds [0 x double], [0 x double]* %vector, i32 0, i64 %iw
  %v2 = load double, double* %vectorp
  %row.inc = add nsw i32 %rowidx, %ilead
  %i.inc = add nsw i32 %i, 1
  %cmp196 = icmp slt i32 %i.inc, %irow
  br i1 %cmp196, label %loop, label %return

return:
  ret void
}

; Remove %i which is only used by the exit test.
; Verify that SCEV can still compute a backedge count from the sign
; extended %n, used for pointer comparison by LFTR.
;
; TODO: Fix for PR13371 currently makes this impossible. See
; IndVarSimplify.cpp hasConcreteDef(). We may want to change to undef rules.
define void @geplftr(i8* %base, i32 %x, i32 %y, i32 %n) nounwind {
; CHECK-LABEL: @geplftr(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    [[X_EXT:%.*]] = sext i32 [[X:%.*]] to i64
; CHECK-NEXT:    [[ADD_PTR:%.*]] = getelementptr inbounds i8, i8* [[BASE:%.*]], i64 [[X_EXT]]
; CHECK-NEXT:    [[Y_EXT:%.*]] = sext i32 [[Y:%.*]] to i64
; CHECK-NEXT:    [[ADD_PTR10:%.*]] = getelementptr inbounds i8, i8* [[ADD_PTR]], i64 [[Y_EXT]]
; CHECK-NEXT:    [[LIM:%.*]] = add i32 [[X]], [[N:%.*]]
; CHECK-NEXT:    [[CMP_PH:%.*]] = icmp ult i32 [[X]], [[LIM]]
; CHECK-NEXT:    br i1 [[CMP_PH]], label [[LOOP_PREHEADER:%.*]], label [[EXIT:%.*]]
; CHECK:       loop.preheader:
; CHECK-NEXT:    br label [[LOOP:%.*]]
; CHECK:       loop:
; CHECK-NEXT:    [[I:%.*]] = phi i32 [ [[INC:%.*]], [[LOOP]] ], [ [[X]], [[LOOP_PREHEADER]] ]
; CHECK-NEXT:    [[APTR:%.*]] = phi i8* [ [[INCDEC_PTR:%.*]], [[LOOP]] ], [ [[ADD_PTR10]], [[LOOP_PREHEADER]] ]
; CHECK-NEXT:    [[INCDEC_PTR]] = getelementptr inbounds i8, i8* [[APTR]], i32 1
; CHECK-NEXT:    store i8 3, i8* [[APTR]]
; CHECK-NEXT:    [[INC]] = add nuw i32 [[I]], 1
; CHECK-NEXT:    [[EXITCOND:%.*]] = icmp ne i32 [[INC]], [[LIM]]
; CHECK-NEXT:    br i1 [[EXITCOND]], label [[LOOP]], label [[EXIT_LOOPEXIT:%.*]]
; CHECK:       exit.loopexit:
; CHECK-NEXT:    br label [[EXIT]]
; CHECK:       exit:
; CHECK-NEXT:    ret void
;
entry:
  %x.ext = sext i32 %x to i64
  %add.ptr = getelementptr inbounds i8, i8* %base, i64 %x.ext
  %y.ext = sext i32 %y to i64
  %add.ptr10 = getelementptr inbounds i8, i8* %add.ptr, i64 %y.ext
  %lim = add i32 %x, %n
  %cmp.ph = icmp ult i32 %x, %lim
  br i1 %cmp.ph, label %loop, label %exit
loop:
  %i = phi i32 [ %x, %entry ], [ %inc, %loop ]
  %aptr = phi i8* [ %add.ptr10, %entry ], [ %incdec.ptr, %loop ]
  %incdec.ptr = getelementptr inbounds i8, i8* %aptr, i32 1
  store i8 3, i8* %aptr
  %inc = add i32 %i, 1
  %cmp = icmp ult i32 %inc, %lim
  br i1 %cmp, label %loop, label %exit

exit:
  ret void
}

; Exercise backedge taken count verification with a never-taken loop.
define void @nevertaken() nounwind uwtable ssp {
; CHECK-LABEL: @nevertaken(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    br label [[LOOP:%.*]]
; CHECK:       loop:
; CHECK-NEXT:    br i1 false, label [[LOOP]], label [[EXIT:%.*]]
; CHECK:       exit:
; CHECK-NEXT:    ret void
;
entry:
  br label %loop
loop:
  %i = phi i32 [ 0, %entry ], [ %inc, %loop ]
  %inc = add nsw i32 %i, 1
  %cmp = icmp sle i32 %inc, 0
  br i1 %cmp, label %loop, label %exit

exit:
  ret void
}

; Test LFTR on an IV whose recurrence start is a non-unit pointer type.
define void @aryptriv([256 x i8]* %base, i32 %n) nounwind {
; CHECK-LABEL: @aryptriv(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    [[IVSTART:%.*]] = getelementptr inbounds [256 x i8], [256 x i8]* [[BASE:%.*]], i32 0, i32 0
; CHECK-NEXT:    [[IVEND:%.*]] = getelementptr inbounds [256 x i8], [256 x i8]* [[BASE]], i32 0, i32 [[N:%.*]]
; CHECK-NEXT:    [[CMP_PH:%.*]] = icmp ult i8* [[IVSTART]], [[IVEND]]
; CHECK-NEXT:    br i1 [[CMP_PH]], label [[LOOP_PREHEADER:%.*]], label [[EXIT:%.*]]
; CHECK:       loop.preheader:
; CHECK-NEXT:    [[TMP0:%.*]] = sext i32 [[N]] to i64
; CHECK-NEXT:    [[SCEVGEP:%.*]] = getelementptr [256 x i8], [256 x i8]* [[BASE]], i64 0, i64 [[TMP0]]
; CHECK-NEXT:    br label [[LOOP:%.*]]
; CHECK:       loop:
; CHECK-NEXT:    [[APTR:%.*]] = phi i8* [ [[INCDEC_PTR:%.*]], [[LOOP]] ], [ [[IVSTART]], [[LOOP_PREHEADER]] ]
; CHECK-NEXT:    [[INCDEC_PTR]] = getelementptr inbounds i8, i8* [[APTR]], i32 1
; CHECK-NEXT:    store i8 3, i8* [[APTR]]
; CHECK-NEXT:    [[EXITCOND:%.*]] = icmp ne i8* [[INCDEC_PTR]], [[SCEVGEP]]
; CHECK-NEXT:    br i1 [[EXITCOND]], label [[LOOP]], label [[EXIT_LOOPEXIT:%.*]]
; CHECK:       exit.loopexit:
; CHECK-NEXT:    br label [[EXIT]]
; CHECK:       exit:
; CHECK-NEXT:    ret void
;
entry:
  %ivstart = getelementptr inbounds [256 x i8], [256 x i8]* %base, i32 0, i32 0
  %ivend = getelementptr inbounds [256 x i8], [256 x i8]* %base, i32 0, i32 %n
  %cmp.ph = icmp ult i8* %ivstart, %ivend
  br i1 %cmp.ph, label %loop, label %exit

loop:
  %aptr = phi i8* [ %ivstart, %entry ], [ %incdec.ptr, %loop ]
  %incdec.ptr = getelementptr inbounds i8, i8* %aptr, i32 1
  store i8 3, i8* %aptr
  %cmp = icmp ult i8* %incdec.ptr, %ivend
  br i1 %cmp, label %loop, label %exit

exit:
  ret void
}