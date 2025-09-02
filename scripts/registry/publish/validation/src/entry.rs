#![no_std]
#![no_main]
#![allow(unused_variables)]
#![allow(unused_imports)]

use userspace;
use userspace::target;

#[unsafe(no_mangle)]
pub extern "C" fn entry(stack_pointer: crate::target::arch::PointerType) -> ! {
    let stack_pointer = crate::target::arch::Pointer(stack_pointer);

    userspace::info!("eXecuting Executable and Linkable Format\n\n");

    let argc = stack_pointer.0 as *const usize;
    userspace::info!("argc={:?}\n", unsafe { *argc });
    let stack = userspace::memory::Stack::from_pointer(stack_pointer);
    stack.print();

    crate::target::os::syscall::exit(30);
}
