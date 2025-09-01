#[unsafe(no_mangle)]
pub extern "C" fn flag_license() -> () {
    userspace::file::print("LICENSE");
}
