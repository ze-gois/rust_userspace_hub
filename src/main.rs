#![allow(incomplete_features)]
#![allow(unused_assignments)]
#![feature(generic_const_exprs)]
#![feature(generic_const_items)]

pub struct Origin;

ample::trait_implement_primitives!();

fn main() {
    // info!("do");
    ample::macros::r#struct!(
        pub Estrutura {
            a : u32,
            b : bool,
            c : Option<u32>
        }
    );
}
