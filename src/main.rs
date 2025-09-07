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

    ample::trait_implement_primitive_array_bytes!(Estrutura);
    // ample::trait_implement_primitive_array_bytes_allgood!();

    let estruturas: [Estrutura; 3] = [
        Estrutura {
            a: 1,
            b: true,
            c: Some(2),
        },
        Estrutura {
            a: 3,
            b: false,
            c: None,
        },
        Estrutura {
            a: 5,
            b: true,
            c: Some(6),
        },
    ];

    ample::macros::r#struct!(
        pub Estrutura2 {
            nb : bool,
            nb2 : bool,
            a : u32,
            c : Option<u32>
        }
    );

    ample::trait_implement_primitive_array_bytes!(Estrutura2);
    // ample::trait_implement_primitive_array_bytes_allgood!();

    let estruturas2: [Estrutura2; 3] = [
        Estrutura2 {
            nb: true,
            nb2: true,
            a: 1,
            c: Some(2),
        },
        Estrutura2 {
            nb: false,
            nb2: false,
            a: 3,
            c: None,
        },
        Estrutura2 {
            nb: true,
            nb2: true,
            a: 5,
            c: Some(6),
        },
    ];

    println!("doto {:?}", estruturas2);

    let estruturas2_bytes =
        <_ as ample::traits::Bytes<crate::Origin, crate::Origin>>::to_le_bytes(&estruturas2);

    println!("nb: {:?}", estruturas2_bytes.len());

    let estruturas2_bytes = [0u8; 33];
    let x = <[Estrutura2; 3] as ample::traits::Bytes<crate::Origin, crate::Origin>>::from_le_bytes(
        estruturas2_bytes,
    );

    println!("doto {:?}", x);
}
