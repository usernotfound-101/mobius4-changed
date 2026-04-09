const { DataTypes } = require('sequelize');
const sequelize = require('../db/sequelize');

const MGO = sequelize.define('mgo', {
  ri: { type: DataTypes.STRING(24), primaryKey: true, allowNull: false },
  ty: { type: DataTypes.INTEGER, allowNull: false, defaultValue: 13 },
  sid: { type: DataTypes.STRING },
  int_cr: { type: DataTypes.STRING },
  rn: { type: DataTypes.STRING, allowNull: false },
  pi: { type: DataTypes.STRING },
  et: { type: DataTypes.STRING(20) },
  ct: { type: DataTypes.STRING(20) },
  lt: { type: DataTypes.STRING(20) },
  acpi: { type: DataTypes.ARRAY(DataTypes.STRING) },
  lbl: { type: DataTypes.ARRAY(DataTypes.STRING) },
  cr: { type: DataTypes.STRING },
  mgd: { type: DataTypes.INTEGER },
  obis: { type: DataTypes.STRING },
  obps: { type: DataTypes.JSONB },
  dc: { type: DataTypes.TEXT },
  loc: { type: DataTypes.GEOMETRY('GEOMETRY', 4326) },
}, {
  tableName: 'mgo',
  timestamps: false,
});

module.exports = MGO;
