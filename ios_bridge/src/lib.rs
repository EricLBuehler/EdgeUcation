use std::{
    ffi::{CStr, CString},
    os::raw::{c_char, c_int},
    panic::{catch_unwind, AssertUnwindSafe},
    thread,
    time::Duration,
};

use image::{DynamicImage, GenericImageView};
use tokio::runtime::Runtime;

use anyhow::Result;
use mistralrs::{DeviceLayerMapMetadata, DeviceMapMetadata, GgufModelBuilder, MemoryGpuConfig, ModelDType, PagedAttentionConfig, PagedAttentionMetaBuilder, PagedCacheType, RequestBuilder, TextMessageRole, TextMessages, UqffVisionModelBuilder, VisionMessages};

#[repr(C)]
pub struct Callbacks {
    pub on_token:
        Option<extern "C" fn(token_utf8: *const c_char, user_ctx: *mut core::ffi::c_void) -> c_int>,
    pub on_done: Option<extern "C" fn(status: i32, user_ctx: *mut core::ffi::c_void)>,
    pub user_ctx: *mut core::ffi::c_void,
}

#[no_mangle]
pub extern "C" fn mrs_init_engine() -> i32 {
    1337 // pretend success
}

// Just echoes back the prompt as tokens, slowly.
#[no_mangle]
pub extern "C" fn mrs_generate_text(prompt: *const c_char, cbs: Callbacks) -> i32 {
    let _ = catch_unwind(AssertUnwindSafe(|| {
        let prompt_str = unsafe { CStr::from_ptr(prompt) }
            .to_string_lossy()
            .to_string();
        for tok in [
            "Hello",
            ",",
            " ",
            "tokens",
            "!",
            "  You said: ",
            &prompt_str,
        ] {
            thread::sleep(Duration::from_millis(120));
            if let Some(cb) = cbs.on_token {
                let c = CString::new(tok).unwrap();
                let rc = cb(c.as_ptr(), cbs.user_ctx);
                if rc != 0 {
                    break;
                }
            }
        }
        if let Some(done) = cbs.on_done {
            done(0, cbs.user_ctx);
        }
    }));
    0
}

async fn start(model_id: String) -> Result<()> {
    let model = UqffVisionModelBuilder::new(model_id, vec!["out-0.uqff".into()])
        .into_inner()
        .with_logging()
        .with_prefix_cache_n(None)
        // .with_force_cpu()
        // .with_device_mapping(mistralrs::DeviceMapSetting::Map(DeviceMapMetadata::from_num_device_layers(vec![DeviceLayerMapMetadata {
        //     ordinal:0,
        //     layers: 34,
        // }])))
        .with_dtype(ModelDType::BF16)
        // .with_paged_attn(|| PagedAttentionConfig::new(
        //     None,
        //     64,
        //     MemoryGpuConfig::ContextSize(1024),
        //     PagedCacheType::F8E4M3,
        // ))?
        .build()
        .await?;

    // std::thread::sleep(Duration::new(10, 0));

    // let model = UqffVisionModelBuilder::new(
    //     model_id,
    //     vec!["phi3.5-vision-instruct-q4k.uqff".into()],
    // )
    // .into_inner()
    // .with_logging()
    // .with_prefix_cache_n(None)
    // .build()
    // .await?;
    // dbg!(std::fs::read_dir(&model_id).unwrap().collect::<Vec<_>>());
    // println!("{}", std::fs::read_to_string(format!("{model_id}/tokenizer_config.json")).unwrap());
    // let model = UqffTextModelBuilder::new(
    //     model_id,
    //     vec!["llama3.2-3b-instruct-afq4.uqff".into()],
    // )
    // .into_inner()
    // .with_logging()
    // .with_prefix_cache_n(Some(0))
    // .build()
    // .await?;
    // let model = GgufModelBuilder::new(
    //     model_id,
    //     vec!["Llama-3.2-3B-Instruct-Q4_K_M.gguf"],
    // )
    // .with_logging()
    // .build()
    // .await?;

    // let messages = VisionMessages::new().add_message(
    //     TextMessageRole::User,
    //     "Hi!"
    // );

    // for i in 0..30 {
    //     std::thread::sleep(Duration::from_secs(1));
    //     println!("WAITING {i}");
    // }

    // let messages = TextMessages::new().add_message(
    //     TextMessageRole::User,
    //     "Hi!"
    // );

    let image: DynamicImage = image::load_from_memory(include_bytes!("mt_washington.jpg"))?;
    dbg!(image.dimensions());

    let messages = VisionMessages::new().add_image_message(
        TextMessageRole::User,
        "What is this?",
        vec![image],
        &model,
    )?;

    // let messages = TextMessages::new().add_message(
    //     TextMessageRole::User,
    //     "hello?",
    // );
    // let messages = RequestBuilder::new().add_message(TextMessageRole::User, "what is graphene").set_sampler_max_len(200);

    let response = model.send_chat_request(messages).await?;

    println!("{}", response.choices[0].message.content.as_ref().unwrap());
    dbg!(&response.usage);

    Ok(())
}

/// Launches model execution for the provided model directory identifier.
#[no_mangle]
pub extern "C" fn mrs_model_run(model_id: *const c_char, out_errno: *mut i32) -> i32 {
    if model_id.is_null() {
        unsafe {
            if !out_errno.is_null() {
                *out_errno = -1;
            }
        }
        return -1;
    }

    let raw_model_id = unsafe { CStr::from_ptr(model_id) }
        .to_string_lossy()
        .to_string();

    let normalized = if raw_model_id.ends_with('/') {
        raw_model_id
    } else {
        format!("{raw_model_id}/")
    };

    match Runtime::new() {
        Ok(rt) => {
            let result = rt.block_on(start(normalized));
            match result {
                Ok(_) => {
                    unsafe {
                        if !out_errno.is_null() {
                            *out_errno = 0;
                        }
                    }
                    0
                }
                Err(err) => {
                    eprintln!("mrs_model_run failed: {err:?}");
                    unsafe {
                        if !out_errno.is_null() {
                            *out_errno = -1;
                        }
                    }
                    -1
                }
            }
        }
        Err(err) => {
            eprintln!("Failed to create Tokio runtime: {err:?}");
            unsafe {
                if !out_errno.is_null() {
                    *out_errno = -1;
                }
            }
            -1
        }
    }
}
