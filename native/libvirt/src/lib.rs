use std::time::Duration;

use rustler::types::atom::ok as atom_ok;
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

type LibResult<T> = NifResult<(Atom, T)>;

fn ok<T>(x: T) -> LibResult<T> {
    Ok((atom_ok(), x))
}

#[derive(Debug, rustler::NifStruct)]
#[rustler(encode)]
#[module = "LuhackVmService.LibVirt.Domain"]
struct Domain {
    id: Option<u32>,
    name: String,
    uuid: String,
    state: DomainState,
}

#[derive(Debug, rustler::NifUnitEnum)]
#[rustler(encode)]
enum DomainState {
    NoState,
    Running,
    Blocked,
    Paused,
    ShutDown,
    ShutOff,
    Crashed,
    PMSuspended,
    Unknown,
}

impl From<virt::domain::DomainState> for DomainState {
    fn from(state: virt::domain::DomainState) -> Self {
        match state {
            virt::domain::VIR_DOMAIN_NOSTATE => DomainState::NoState,
            virt::domain::VIR_DOMAIN_RUNNING => DomainState::Running,
            virt::domain::VIR_DOMAIN_BLOCKED => DomainState::Blocked,
            virt::domain::VIR_DOMAIN_PAUSED => DomainState::Paused,
            virt::domain::VIR_DOMAIN_SHUTDOWN => DomainState::ShutDown,
            virt::domain::VIR_DOMAIN_SHUTOFF => DomainState::ShutOff,
            virt::domain::VIR_DOMAIN_CRASHED => DomainState::Crashed,
            virt::domain::VIR_DOMAIN_PMSUSPENDED => DomainState::PMSuspended,
            _ => DomainState::Unknown,
        }
    }
}

impl TryFrom<virt::domain::Domain> for Domain {
    type Error = rustler::Error;

    fn try_from(dom: virt::domain::Domain) -> Result<Self, Self::Error> {
        let id = dom.get_id();
        let name = dom.get_name().map_err(virt_to_nifresult)?;
        let uuid = dom.get_uuid_string().map_err(virt_to_nifresult)?;
        let (state, _) = dom.get_state().map_err(virt_to_nifresult)?;
        let state = DomainState::from(state);

        Ok(Domain {
            id,
            name,
            uuid,
            state,
        })
    }
}

#[rustler::nif]
fn list_doms() -> LibResult<Vec<Domain>> {
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

    ok(doms)
}

#[rustler::nif]
fn get_dom(uuid: &str) -> LibResult<Domain> {
    let mut conn = connect()?;

    let dom = virt::domain::Domain::lookup_by_uuid_string(&conn, uuid)
        .map_err(virt_to_nifresult)?
        .try_into()?;

    conn.close().map_err(virt_to_nifresult)?;

    ok(dom)
}

#[rustler::nif]
fn start_dom(uuid: &str) -> NifResult<Atom> {
    let mut conn = connect()?;

    let dom =
        virt::domain::Domain::lookup_by_uuid_string(&conn, uuid).map_err(virt_to_nifresult)?;

    dom.create().map_err(virt_to_nifresult)?;

    conn.close().map_err(virt_to_nifresult)?;

    Ok(atom_ok())
}

#[rustler::nif]
fn stop_dom(uuid: &str) -> NifResult<Atom> {
    let mut conn = connect()?;

    let dom =
        virt::domain::Domain::lookup_by_uuid_string(&conn, uuid).map_err(virt_to_nifresult)?;

    dom.destroy().map_err(virt_to_nifresult)?;

    conn.close().map_err(virt_to_nifresult)?;

    Ok(atom_ok())
}

#[rustler::nif]
fn delete_dom(uuid: &str) -> NifResult<Atom> {
    let mut conn = connect()?;

    let dom =
        virt::domain::Domain::lookup_by_uuid_string(&conn, uuid).map_err(virt_to_nifresult)?;

    let _ = dom.destroy();
    dom.undefine().map_err(virt_to_nifresult)?;

    conn.close().map_err(virt_to_nifresult)?;

    Ok(atom_ok())
}

#[rustler::nif]
fn get_dom_vnc_port(uuid: &str) -> LibResult<u16> {
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
        ok(port as u16)
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
