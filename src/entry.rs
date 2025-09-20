#![no_std]
#![no_main]
#![allow(unused_variables)]
#![allow(unused_imports)]
#![allow(incomplete_features)]
#![allow(unused_assignments)]
#![feature(generic_const_exprs)]
#![feature(generic_const_items)]
#![feature(const_trait_impl)]
#![feature(fundamental)]

use userspace;
use userspace::info;
use userspace::memory::heap::Allocating;
use userspace::target;

#[derive(Debug)]
pub struct Origin;

ample::trait_implement_primitives!();

#[unsafe(no_mangle)]
pub extern "C" fn entry(stack_pointer: crate::target::arch::PointerType) -> ! {
    let stack_pointer = crate::target::arch::Pointer(stack_pointer);

    info!("eXecuting Executable and Linkable Format\n\n\n");

    let argc = stack_pointer.0 as *const usize;
    info!("argc={:?}\n\n", unsafe { *argc });
    let stack = userspace::memory::Stack::from_pointer(stack_pointer);
    stack.print();
    stack.arguments.print();

    let arg0 = stack.arguments.get(0).unwrap();
    let arg0_pointer = arg0.pointer;

    if !arg0.pointer.0.is_null() {
        unsafe {
            let cstr = core::ffi::CStr::from_ptr(arg0.pointer.0 as *mut i8);
            let self_path = cstr.to_str().unwrap();

            userspace::info!("\n{:?}\n\n", self_path);

            let self_fd = userspace::file::open(self_path);

            let (fd, stat, ptr) = userspace::file::load(self_path).unwrap();

            info!("fd={:?}\n\n stat={:?}\n\n ptr={:?}\n\n", fd, stat, ptr);

            for c in 0..=15 {
                info!("*ptr.add({:?}) as char == {:?}\n", c, *ptr.add(c) as char);
            }

            let entries = userspace::memory::stack::auxiliary::Entry::allocate_slice(10);

            for e in entries.iter_mut() {
                info!("{:?}\n", e);
            }

            let identifier = userspace::file::format::elf::header::Identifier::from_path(self_path);
            userspace::info!("{:?}\n\n", identifier);
        }
    }

    // let uchar32 = userspace::file::format::elf::dtype::class_32::UChar(3);

    info!("<<< we\n");
    info!("<<< we are\n");
    info!("<<< we are executing\n");
    info!("<<< we are executing an\n");
    info!("<<< we are executing an executable\n");
    info!("<<< we are executing an executable and\n");
    info!("<<< we are executing an executable and linkable\n");
    info!("<<< we are executing an executable and linkable format\n");
    info!("<<< we are executing an executable and linkable format\n\n\n");
    panic!();
}
