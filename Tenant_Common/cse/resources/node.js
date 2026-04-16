const { nod_create_schema, nod_update_schema } = require('../validation/res_schema');
const { generate_ri, get_cur_time, get_default_et, convert_loc_to_geoJson, get_loc_attribute } = require('../utils');
const enums = require('../../config/enums');
const NOD = require('../../models/nod-model');
const Lookup = require('../../models/lookup-model');
const logger = require('../../logger').child({ module: 'nod' });

const nod_parent_res_types = ['cb'];

async function create_a_nod(req_prim, resp_prim) {
  const prim_res = req_prim.pc['m2m:nod'];
  if (!prim_res) {
    resp_prim.rsc = enums.rsc_str['BAD_REQUEST'];
    resp_prim.pc = { 'm2m:dbg': 'm2m:nod is missing in request body' };
    return;
  }

  const validated = nod_create_schema.validate(prim_res);
  if (validated.error) {
    const { message, path } = validated.error.details[0];
    resp_prim.rsc = enums.rsc_str['BAD_REQUEST'];
    resp_prim.pc = { 'm2m:dbg': path[0] + ' => ' + message.replace(/"/g, '') };
    return;
  }

  const parent_ty = req_prim.to_ty;
  if (!nod_parent_res_types.includes(enums.ty_str[parent_ty.toString()])) {
    resp_prim.rsc = enums.rsc_str['INVALID_CHILD_RESOURCE_TYPE'];
    resp_prim.pc = { 'm2m:dbg': 'cannot create <nod> to this parent resource type' };
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
    await NOD.create({
      ri,
      ty: 14,
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
      ni: prim_res.ni || null,
      hcl: prim_res.hcl || null,
      mgca: prim_res.mgca || null,
      loc: prim_res.loc || null,
    });

    await Lookup.create({
      ri,
      ty: 14,
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
    await retrieve_a_nod(tmp_req, tmp_resp);
    resp_prim.pc = tmp_resp.pc;
  } catch (err) {
    logger.error({ err }, 'create_a_nod failed');
    resp_prim.rsc = enums.rsc_str['BAD_REQUEST'];
    resp_prim.pc = { 'm2m:dbg': err.message };
  }
}

async function retrieve_a_nod(req_prim, resp_prim) {
  const nod_obj = { 'm2m:nod': {} };
  const ri = req_prim.ri;

  try {
    const db_res = await NOD.findByPk(ri);
    if (!db_res) {
      resp_prim.rsc = enums.rsc_str['NOT_FOUND'];
      resp_prim.pc = { 'm2m:dbg': 'NOD resource not found' };
      return;
    }

    if (req_prim && req_prim.int_cr_req === true) {
      nod_obj['m2m:nod'].int_cr = db_res.int_cr;
    }

    nod_obj['m2m:nod'].ty = db_res.ty;
    nod_obj['m2m:nod'].et = db_res.et;
    nod_obj['m2m:nod'].ct = db_res.ct;
    nod_obj['m2m:nod'].lt = db_res.lt;
    nod_obj['m2m:nod'].ri = db_res.ri;
    nod_obj['m2m:nod'].rn = db_res.rn;
    nod_obj['m2m:nod'].pi = db_res.pi;

    if (db_res.acpi) nod_obj['m2m:nod'].acpi = db_res.acpi;
    if (db_res.lbl) nod_obj['m2m:nod'].lbl = db_res.lbl;
    if (db_res.cr) nod_obj['m2m:nod'].cr = db_res.cr;
    if (db_res.ni) nod_obj['m2m:nod'].ni = db_res.ni;
    if (db_res.hcl !== null && db_res.hcl !== undefined) nod_obj['m2m:nod'].hcl = db_res.hcl;
    if (db_res.mgca) nod_obj['m2m:nod'].mgca = db_res.mgca;
    if (db_res.loc) nod_obj['m2m:nod'].loc = get_loc_attribute(db_res.loc);
  } catch (err) {
    logger.error({ err }, 'retrieve_a_nod failed');
    resp_prim.rsc = enums.rsc_str['BAD_REQUEST'];
    resp_prim.pc = { 'm2m:dbg': err.message };
    return;
  }

  resp_prim.pc = nod_obj;
}

async function update_a_nod(req_prim, resp_prim) {
  const prim_res = req_prim.pc['m2m:nod'];
  if (!prim_res) {
    resp_prim.rsc = enums.rsc_str['BAD_REQUEST'];
    resp_prim.pc = { 'm2m:dbg': 'm2m:nod is missing in request body' };
    return;
  }

  const validated = nod_update_schema.validate(prim_res);
  if (validated.error) {
    const { message, path } = validated.error.details[0];
    resp_prim.rsc = enums.rsc_str['BAD_REQUEST'];
    resp_prim.pc = { 'm2m:dbg': path[0] + ' => ' + message.replace(/"/g, '') };
    return;
  }

  const ri = req_prim.ri;

  try {
    const db_res = await NOD.findByPk(ri);
    if (!db_res) {
      resp_prim.rsc = enums.rsc_str['NOT_FOUND'];
      resp_prim.pc = { 'm2m:dbg': 'NOD resource not found' };
      return;
    }

    db_res.lt = get_cur_time();

    if (prim_res.et !== undefined) db_res.et = prim_res.et;
    if (prim_res.acpi !== undefined) db_res.acpi = prim_res.acpi;
    if (prim_res.lbl !== undefined) db_res.lbl = prim_res.lbl;
    if (prim_res.ni !== undefined) db_res.ni = prim_res.ni;
    if (prim_res.hcl !== undefined) db_res.hcl = prim_res.hcl;
    if (prim_res.mgca !== undefined) db_res.mgca = prim_res.mgca;

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
    await retrieve_a_nod(tmp_req, tmp_resp);
    resp_prim.pc = tmp_resp.pc;
  } catch (err) {
    logger.error({ err }, 'update_a_nod failed');
    resp_prim.rsc = enums.rsc_str['BAD_REQUEST'];
    resp_prim.pc = { 'm2m:dbg': err.message };
  }
}

module.exports = {
  create_a_nod,
  retrieve_a_nod,
  update_a_nod,
};
