// RUN: %target-swift-frontend -Xllvm -new-mangling-for-tests -emit-silgen -sdk %S/Inputs/ -I %S/Inputs -enable-source-import %s | %FileCheck %s

// REQUIRES: objc_interop

import Foundation
import objc_extensions_helper

class Sub : Base {}

extension Sub {
  override var prop: String! {
    didSet {
      // Ignore it.
    }

    // Make sure that we are generating the @objc thunk and are calling the actual method.
    //
    // CHECK-LABEL: sil hidden [thunk] @_T015objc_extensions3SubC4propSQySSGfgTo : $@convention(objc_method) (Sub) -> @autoreleased Optional<NSString> {
    // CHECK: bb0([[SELF:%.*]] : $Sub):
    // CHECK: [[SELF_COPY:%.*]] = copy_value [[SELF]]
    // CHECK: [[GETTER_FUNC:%.*]] = function_ref @_T015objc_extensions3SubC4propSQySSGfg : $@convention(method) (@guaranteed Sub) -> @owned Optional<String>
    // CHECK: apply [[GETTER_FUNC]]([[SELF_COPY]])
    // CHECK: destroy_value [[SELF_COPY]]
    // CHECK: } // end sil function '_T015objc_extensions3SubC4propSQySSGfgTo'

    // Then check the body of the getter calls the super_method.
    // CHECK-LABEL: sil hidden @_T015objc_extensions3SubC4propSQySSGfg : $@convention(method) (@guaranteed Sub) -> @owned Optional<String> {
    // CHECK: bb0([[SELF:%.*]] : $Sub):
    // CHECK: [[SELF_COPY:%.*]] = copy_value [[SELF]]
    // CHECK: [[SELF_COPY_CAST:%.*]] = upcast [[SELF_COPY]] : $Sub to $Base
    // CHECK: [[SUPER_METHOD:%.*]] = super_method [volatile] [[SELF_COPY]] : $Sub, #Base.prop!getter.1.foreign
    // CHECK: [[RESULT:%.*]] = apply [[SUPER_METHOD]]([[SELF_COPY_CAST]])
    // CHECK: bb3(
    // CHECK: destroy_value [[SELF_COPY]]
    // CHECK: } // end sil function '_T015objc_extensions3SubC4propSQySSGfg'

    // Then check the setter @objc thunk.
    //
    // TODO: This codegens using a select_enum + cond_br. It would be better to
    // just use a switch_enum so we can consume the value. This change will be
    // necessary in a semantic ARC world.
    //
    // CHECK-LABEL: sil hidden [thunk] @_T015objc_extensions3SubC4propSQySSGfsTo : $@convention(objc_method) (Optional<NSString>, Sub) -> () {
    // CHECK: bb0([[NEW_VALUE:%.*]] : $Optional<NSString>, [[SELF:%.*]] : $Sub):
    // CHECK: [[SELF_COPY:%.*]] = copy_value [[SELF]] : $Sub
    // CHECK: bb1:
    // CHECK: bb3([[BRIDGED_NEW_VALUE:%.*]] : $Optional<String>):
    // CHECK:   [[NORMAL_FUNC:%.*]] = function_ref @_T015objc_extensions3SubC4propSQySSGfs : $@convention(method) (@owned Optional<String>, @guaranteed Sub) -> ()
    // CHECK:   apply [[NORMAL_FUNC]]([[BRIDGED_NEW_VALUE]], [[SELF_COPY]])
    // CHECK:   destroy_value [[SELF_COPY]]
    // CHECK: } // end sil function '_T015objc_extensions3SubC4propSQySSGfsTo'

    // Then check the body of the actually setter value and make sure that we
    // call the didSet function.
    // CHECK-LABEL: sil hidden @_T015objc_extensions3SubC4propSQySSGfs : $@convention(method) (@owned Optional<String>, @guaranteed Sub) -> () {

    // First we get the old value.
    // CHECK: bb0([[NEW_VALUE:%.*]] : $Optional<String>, [[SELF:%.*]] : $Sub):
    // CHECK:   [[SELF_COPY:%.*]] = copy_value [[SELF]]
    // CHECK:   [[UPCAST_SELF_COPY:%.*]] = upcast [[SELF_COPY]] : $Sub to $Base
    // CHECK:   [[GET_SUPER_METHOD:%.*]] = super_method [volatile] [[SELF_COPY]] : $Sub, #Base.prop!getter.1.foreign : (Base) -> () -> String!, $@convention(objc_method) (Base) -> @autoreleased Optional<NSString>
    // CHECK:   [[OLD_NSSTRING:%.*]] = apply [[GET_SUPER_METHOD]]([[UPCAST_SELF_COPY]])

    // CHECK: bb3([[OLD_NSSTRING_BRIDGED:%.*]] : $Optional<String>):
    // This next line is completely not needed. But we are emitting it now.
    // CHECK:   destroy_value [[SELF_COPY]]
    // CHECK:   [[SELF_COPY:%.*]] = copy_value [[SELF]]
    // CHECK:   [[UPCAST_SELF_COPY:%.*]] = upcast [[SELF_COPY]] : $Sub to $Base
    // CHECK:   [[SET_SUPER_METHOD:%.*]] = super_method [volatile] [[SELF_COPY]] : $Sub, #Base.prop!setter.1.foreign : (Base) -> (String!) -> (), $@convention(objc_method) (Optional<NSString>, Base) -> ()
    // CHECK: bb4:
    // CHECK: bb6([[BRIDGED_NEW_STRING:%.*]] : $Optional<NSString>):
    // CHECK:    apply [[SET_SUPER_METHOD]]([[BRIDGED_NEW_STRING]], [[UPCAST_SELF_COPY]])
    // CHECK:    destroy_value [[BRIDGED_NEW_STRING]]
    // CHECK:    destroy_value [[SELF_COPY]]
    // CHECK:    [[DIDSET_NOTIFIER:%.*]] = function_ref @_T015objc_extensions3SubC4propSQySSGfW : $@convention(method) (@owned Optional<String>, @guaranteed Sub) -> ()
    // CHECK:    [[BORROWED_OLD_NSSTRING_BRIDGED:%.*]] = begin_borrow [[OLD_NSSTRING_BRIDGED]]
    // CHECK:    [[COPIED_OLD_NSSTRING_BRIDGED:%.*]] = copy_value [[BORROWED_OLD_NSSTRING_BRIDGED]]
    // CHECK:    end_borrow [[BORROWED_OLD_NSSTRING_BRIDGED]] from [[OLD_NSSTRING_BRIDGED]]
    // This is an identity cast that should be eliminated by SILGen peepholes.
    // CHECK:    apply [[DIDSET_NOTIFIER]]([[COPIED_OLD_NSSTRING_BRIDGED]], [[SELF]])
    // CHECK:    destroy_value [[OLD_NSSTRING_BRIDGED]]
    // CHECK:    destroy_value [[NEW_VALUE]]
    // CHECK: } // end sil function '_T015objc_extensions3SubC4propSQySSGfs'

  }

  func foo() {
  }

  override func objCBaseMethod() {}
}

// CHECK-LABEL: sil hidden @_T015objc_extensions20testOverridePropertyyAA3SubCF
func testOverrideProperty(_ obj: Sub) {
  // CHECK: bb0([[ARG:%.*]] : $Sub):
  // CHECK: [[BORROWED_ARG:%.*]] = begin_borrow [[ARG]]
  // CHECK: = class_method [volatile] [[BORROWED_ARG]] : $Sub, #Sub.prop!setter.1.foreign : (Sub) -> (String!) -> ()
  obj.prop = "abc"
} // CHECK: } // end sil function '_T015objc_extensions20testOverridePropertyyAA3SubCF'

testOverrideProperty(Sub())

// CHECK-LABEL: sil shared [thunk] @_T015objc_extensions3SubC3fooyyFTc
// CHECK:         function_ref @_T015objc_extensions3SubC3fooyyFTD
// CHECK: } // end sil function '_T015objc_extensions3SubC3fooyyFTc'
// CHECK:       sil shared [transparent] [thunk] @_T015objc_extensions3SubC3fooyyFTD
// CHECK:       bb0([[SELF:%.*]] : $Sub):
// CHECK:         [[SELF_COPY:%.*]] = copy_value [[SELF]]
// CHECK:         class_method [volatile] [[SELF_COPY]] : $Sub, #Sub.foo!1.foreign
// CHECK: } // end sil function '_T015objc_extensions3SubC3fooyyFTD'
func testCurry(_ x: Sub) {
  _ = x.foo
}

extension Sub {
  var otherProp: String {
    get { return "hello" }
    set { }
  }
}

class SubSub : Sub {
  // CHECK-LABEL: sil hidden @_T015objc_extensions03SubC0C14objCBaseMethodyyF
  // CHECK: bb0([[SELF:%.*]] : $SubSub):
  // CHECK:   [[SELF_COPY:%.*]] = copy_value [[SELF]]
  // CHECK:   super_method [volatile] [[SELF_COPY]] : $SubSub, #Sub.objCBaseMethod!1.foreign : (Sub) -> () -> (), $@convention(objc_method) (Sub) -> ()
  // CHECK: } // end sil function '_T015objc_extensions03SubC0C14objCBaseMethodyyF'
  override func objCBaseMethod() {
    super.objCBaseMethod()
  }
}

extension SubSub {
  // CHECK-LABEL: sil hidden @_T015objc_extensions03SubC0C9otherPropSSfs
  // CHECK: bb0([[NEW_VALUE:%.*]] : $String, [[SELF:%.*]] : $SubSub):
  // CHECK:   [[SELF_COPY_1:%.*]] = copy_value [[SELF]]
  // CHECK:   = super_method [volatile] [[SELF_COPY_1]] : $SubSub, #Sub.otherProp!getter.1.foreign
  // CHECK:   [[SELF_COPY_2:%.*]] = copy_value [[SELF]]
  // CHECK:   = super_method [volatile] [[SELF_COPY_2]] : $SubSub, #Sub.otherProp!setter.1.foreign
  // CHECK: } // end sil function '_T015objc_extensions03SubC0C9otherPropSSfs'
  override var otherProp: String {
    didSet {
      // Ignore it.
    }
  }
}

// SR-1025
extension Base {
  fileprivate static var x = 1
}

// CHECK-LABEL: sil hidden @_T015objc_extensions19testStaticVarAccessyyF
func testStaticVarAccess() {
  // CHECK: [[F:%.*]] = function_ref @_T0So4BaseC15objc_extensionsE1x33_1F05E59585E0BB585FCA206FBFF1A92DLLSifau
  // CHECK: [[PTR:%.*]] = apply [[F]]()
  // CHECK: [[ADDR:%.*]] = pointer_to_address [[PTR]]
  _ = Base.x
}
