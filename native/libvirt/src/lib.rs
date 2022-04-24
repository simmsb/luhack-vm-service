use std::time::Duration;

use rustler::types::atom::ok;
use rustler::{Atom, NifResult};
use virt::connect::Connect;

rustler::atoms! {
    libvirt,
}

fn virt_to_nifresult(err: virt::error::Error) -> rustler::Error {
    rustler::Error::Term(Box::new((libvirt(), err.to_string())))
}

fn connect() -> NifResult<Connect> {
    let mut err;
    let mut n = 0;

    loop {
        match Connect::open("") {
            Ok(conn) => return Ok(conn),
            Err(e) => err = e,
        }

        n += 1;
        if n > 3 {
            break;
        }

        std::thread::sleep(Duration::from_millis(300));
    }

    Err(virt_to_nifresult(err))
}

#[derive(Debug, rustler::NifStruct)]
#[rustler(encode)]
#[module = "LuhackVmService.LibVirt.Domain"]
struct Domain {
    id: Option<u32>,
    name: String,
    uuid: String,
}

impl TryFrom<virt::domain::Domain> for Domain {
    type Error = rustler::Error;

    fn try_from(dom: virt::domain::Domain) -> Result<Self, Self::Error> {
        let id = dom.get_id();
        let name = dom.get_name().map_err(virt_to_nifresult)?;
        let uuid = dom.get_uuid_string().map_err(virt_to_nifresult)?;

        Ok(Domain { id, name, uuid })
    }
}

#[rustler::nif]
fn list_doms() -> NifResult<Vec<Domain>> {
    let mut conn = connect()?;

    let flags = virt::connect::VIR_CONNECT_LIST_DOMAINS_ACTIVE
        | virt::connect::VIR_CONNECT_LIST_DOMAINS_INACTIVE;

    let doms = conn
        .list_all_domains(flags)
        .map_err(virt_to_nifresult)?
        .into_iter()
        .map(Domain::try_from)
        .collect::<Result<Vec<_>, _>>()?;

    conn.close().map_err(virt_to_nifresult)?;

    Ok(doms)
}

#[rustler::nif]
fn get_dom(uuid: &str) -> NifResult<Domain> {
    let mut conn = connect()?;

    let dom = virt::domain::Domain::lookup_by_uuid_string(&conn, uuid)
        .map_err(virt_to_nifresult)?
        .try_into()?;

    conn.close().map_err(virt_to_nifresult)?;

    Ok(dom)
}

#[rustler::nif]
fn start_dom(uuid: &str) -> NifResult<Atom> {
    let mut conn = connect()?;

    let dom =
        virt::domain::Domain::lookup_by_uuid_string(&conn, uuid).map_err(virt_to_nifresult)?;

    dom.create().map_err(virt_to_nifresult)?;

    conn.close().map_err(virt_to_nifresult)?;

    Ok(ok())
}

#[rustler::nif]
fn stop_dom(uuid: &str) -> NifResult<Atom> {
    let mut conn = connect()?;

    let dom =
        virt::domain::Domain::lookup_by_uuid_string(&conn, uuid).map_err(virt_to_nifresult)?;

    dom.destroy().map_err(virt_to_nifresult)?;

    conn.close().map_err(virt_to_nifresult)?;

    Ok(ok())
}

#[rustler::nif]
fn delete_dom(uuid: &str) -> NifResult<Atom> {
    let mut conn = connect()?;

    let dom =
        virt::domain::Domain::lookup_by_uuid_string(&conn, uuid).map_err(virt_to_nifresult)?;

    let _ = dom.destroy();
    dom.undefine().map_err(virt_to_nifresult)?;

    conn.close().map_err(virt_to_nifresult)?;

    Ok(ok())
}

#[rustler::nif]
fn get_dom_vnc_port(uuid: &str) -> NifResult<u16> {
    let mut conn = connect()?;

    let dom =
        virt::domain::Domain::lookup_by_uuid_string(&conn, uuid).map_err(virt_to_nifresult)?;

    let xml = dom.get_xml_desc(0).map_err(virt_to_nifresult)?;
    let tree = roxmltree::Document::parse(&xml)
        .map_err(|_| rustler::Error::Term(Box::new("xml_parse_fail")))?;
    let graphics = tree
        .descendants()
        .find(|n| n.tag_name().name() == "graphics")
        .ok_or_else(|| rustler::Error::Term(Box::new("xml_no_graphics")))?;
    let port = graphics.attribute("port").unwrap().parse::<i32>().unwrap();

    conn.close().map_err(virt_to_nifresult)?;

    if port < 0 {
        Err(rustler::Error::Term(Box::new("no_port_allocated")))
    } else {
        Ok(port as u16)
    }
}

fn on_load(_env: rustler::Env, _invo: rustler::Term) -> bool {
    true
}

rustler::init!(
    "Elixir.LuhackVmService.LibVirt",
    [
        list_doms,
        get_dom,
        start_dom,
        stop_dom,
        delete_dom,
        get_dom_vnc_port
    ],
    load = on_load
);
