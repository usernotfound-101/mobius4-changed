const { mgo_create_schema, mgo_update_schema } = require('../validation/res_schema');
const { generate_ri, get_cur_time, get_default_et, convert_loc_to_geoJson, get_loc_attribute } = require('../utils');
const enums = require('../../config/enums');
const MGO = require('../../models/mgo-model');
const Lookup = require('../../models/lookup-model');
const logger = require('../../logger').child({ module: 'mgo' });

const mgo_parent_res_types = ['nod'];

async function create_a_mgo(req_prim, resp_prim) {
  const prim_res = req_prim.pc['m2m:mgo'];
  if (!prim_res) {
    resp_prim.rsc = enums.rsc_str['BAD_REQUEST'];
    resp_prim.pc = { 'm2m:dbg': 'm2m:mgo is missing in request body' };
    return;
  }

  const validated = mgo_create_schema.validate(prim_res);
  if (validated.error) {
    const { message, path } = validated.error.details[0];
    resp_prim.rsc = enums.rsc_str['BAD_REQUEST'];
    resp_prim.pc = { 'm2m:dbg': path[0] + ' => ' + message.replace(/"/g, '') };
    return;
  }

  const parent_ty = req_prim.to_ty;
  if (!mgo_parent_res_types.includes(enums.ty_str[parent_ty.toString()])) {
    resp_prim.rsc = enums.rsc_str['INVALID_CHILD_RESOURCE_TYPE'];
    resp_prim.pc = { 'm2m:dbg': 'cannot create <mgo> to this parent resource type' };
    return;
  }

  if (prim_res.loc) {
    await convert_loc_to_geoJson(prim_res, resp_prim);
    if (resp_prim.rsc) {
      return;
    }
  }

  const ri = generate_ri();
  const now = get_cur_time();
  const et = get_default_et();
  const sid = req_prim.sid + '/' + prim_res.rn;

  try {
    await MGO.create({
      ri,
      ty: 13,
      rn: prim_res.rn,
      pi: req_prim.ri,
      sid,
      int_cr: req_prim.fr,
      et: prim_res.et || et,
      ct: now,
      lt: now,
      cr: prim_res.cr === null ? req_prim.fr : null,
      acpi: prim_res.acpi || null,
      lbl: prim_res.lbl || null,
      mgd: prim_res.mgd,
      obis: prim_res.obis || null,
      obps: prim_res.obps || null,
      dc: prim_res.dc || null,
      loc: prim_res.loc || null,
    });

    await Lookup.create({
      ri,
      ty: 13,
      rn: prim_res.rn,
      sid,
      lvl: sid.split('/').length,
      pi: req_prim.ri,
      cr: prim_res.cr === null ? req_prim.fr : null,
      int_cr: req_prim.fr,
      et: prim_res.et || et,
      loc: prim_res.loc || null,
    });

    const tmp_req = { ri }, tmp_resp = {};
    await retrieve_a_mgo(tmp_req, tmp_resp);
    resp_prim.pc = tmp_resp.pc;
  } catch (err) {
    logger.error({ err }, 'create_a_mgo failed');
    resp_prim.rsc = enums.rsc_str['BAD_REQUEST'];
    resp_prim.pc = { 'm2m:dbg': err.message };
  }
}

async function retrieve_a_mgo(req_prim, resp_prim) {
  const mgo_obj = { 'm2m:mgo': {} };
  const ri = req_prim.ri;

  try {
    const db_res = await MGO.findByPk(ri);
    if (!db_res) {
      resp_prim.rsc = enums.rsc_str['NOT_FOUND'];
      resp_prim.pc = { 'm2m:dbg': 'MGO resource not found' };
      return;
    }

    if (req_prim && req_prim.int_cr_req === true) {
      mgo_obj['m2m:mgo'].int_cr = db_res.int_cr;
    }

    mgo_obj['m2m:mgo'].ty = db_res.ty;
    mgo_obj['m2m:mgo'].et = db_res.et;
    mgo_obj['m2m:mgo'].ct = db_res.ct;
    mgo_obj['m2m:mgo'].lt = db_res.lt;
    mgo_obj['m2m:mgo'].ri = db_res.ri;
    mgo_obj['m2m:mgo'].rn = db_res.rn;
    mgo_obj['m2m:mgo'].pi = db_res.pi;
    mgo_obj['m2m:mgo'].mgd = db_res.mgd;

    if (db_res.acpi) mgo_obj['m2m:mgo'].acpi = db_res.acpi;
    if (db_res.lbl) mgo_obj['m2m:mgo'].lbl = db_res.lbl;
    if (db_res.cr) mgo_obj['m2m:mgo'].cr = db_res.cr;
    if (db_res.obis) mgo_obj['m2m:mgo'].obis = db_res.obis;
    if (db_res.obps) mgo_obj['m2m:mgo'].obps = db_res.obps;
    if (db_res.dc) mgo_obj['m2m:mgo'].dc = db_res.dc;
    if (db_res.loc) mgo_obj['m2m:mgo'].loc = get_loc_attribute(db_res.loc);
  } catch (err) {
    logger.error({ err }, 'retrieve_a_mgo failed');
    resp_prim.rsc = enums.rsc_str['BAD_REQUEST'];
    resp_prim.pc = { 'm2m:dbg': err.message };
    return;
  }

  resp_prim.pc = mgo_obj;
}

async function update_a_mgo(req_prim, resp_prim) {
  const prim_res = req_prim.pc['m2m:mgo'];
  if (!prim_res) {
    resp_prim.rsc = enums.rsc_str['BAD_REQUEST'];
    resp_prim.pc = { 'm2m:dbg': 'm2m:mgo is missing in request body' };
    return;
  }

  const validated = mgo_update_schema.validate(prim_res);
  if (validated.error) {
    const { message, path } = validated.error.details[0];
    resp_prim.rsc = enums.rsc_str['BAD_REQUEST'];
    resp_prim.pc = { 'm2m:dbg': path[0] + ' => ' + message.replace(/"/g, '') };
    return;
  }

  const ri = req_prim.ri;

  try {
    const db_res = await MGO.findByPk(ri);
    if (!db_res) {
      resp_prim.rsc = enums.rsc_str['NOT_FOUND'];
      resp_prim.pc = { 'm2m:dbg': 'MGO resource not found' };
      return;
    }

    db_res.lt = get_cur_time();

    if (prim_res.et !== undefined) db_res.et = prim_res.et;
    if (prim_res.acpi !== undefined) db_res.acpi = prim_res.acpi;
    if (prim_res.lbl !== undefined) db_res.lbl = prim_res.lbl;
    if (prim_res.obis !== undefined) db_res.obis = prim_res.obis;
    if (prim_res.obps !== undefined) db_res.obps = prim_res.obps;
    if (prim_res.dc !== undefined) db_res.dc = prim_res.dc;

    if (prim_res.loc !== undefined) {
      if (prim_res.loc === null) {
        db_res.loc = null;
      } else {
        await convert_loc_to_geoJson(prim_res, resp_prim);
        if (resp_prim.rsc) {
          return;
        }
        db_res.loc = prim_res.loc;
      }
    }

    await db_res.save();

    if (db_res.loc !== undefined) {
      await Lookup.update({ loc: db_res.loc }, { where: { ri } });
    }

    const tmp_req = { ri }, tmp_resp = {};
    await retrieve_a_mgo(tmp_req, tmp_resp);
    resp_prim.pc = tmp_resp.pc;
  } catch (err) {
    logger.error({ err }, 'update_a_mgo failed');
    resp_prim.rsc = enums.rsc_str['BAD_REQUEST'];
    resp_prim.pc = { 'm2m:dbg': err.message };
  }
}

module.exports = {
  create_a_mgo,
  retrieve_a_mgo,
  update_a_mgo,
};
