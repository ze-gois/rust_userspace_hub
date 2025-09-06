#![allow(incomplete_features)]
#![allow(unused_assignments)]
#![feature(generic_const_exprs)]
#![feature(generic_const_items)]

// use userspace;
// use userspace::info;
// use userspace::target;
pub struct Origin;

ample::trait_implement_primitives!();

// use ample::traits::Bytes;

// ample::trait_implement_primitive_bytes!(u32, u8);

fn main() {
    // info!("do");
    ample::macros::r#struct!(pub Estrutura {
        a : u32,
        b : bool,
        c : Option<u32>
    });

    let estrutura = Estrutura {
        a: 42,
        b: true,
        c: Some(23),
    };

    let bytes = <Estrutura as ample::traits::Bytes<crate::Origin, crate::Origin>>::to_bytes(
        &estrutura, true,
    );

    let estrutura2 =
        <Estrutura as ample::traits::Bytes<crate::Origin, crate::Origin>>::from_bytes(bytes, true);

    println!("doto {:?}", estrutura2);
}
