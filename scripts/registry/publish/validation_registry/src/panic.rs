use core::panic::PanicInfo;

pub use userspace::info;

#[panic_handler]
pub fn panic(info: &PanicInfo) -> ! {
    if let Some(location) = info.location() {
        // Example: send to UART or RTT instead of println
        let filename = location.file();
        let fileline = location.line() as u32;
        let filecolumn = location.column() as u32;
        info!("\npanic at file:{}:{}:{}\n", filename, fileline, filecolumn);
    }
    let mut count = 5;
    loop {
        count -= 1;
        info!("x.");
        if count == 0 {
            info!("..:");
            // unsafe { core::arch::asm!("call entry") };
            userspace::target::os::syscall::exit(23);
        }
    }
}
