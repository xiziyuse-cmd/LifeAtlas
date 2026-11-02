import {test} from 'node:test';
import assert from 'node:assert/strict';
import {skinImage,skinInput,skinIdentified,skinPlanned} from './skincare.js';
test('image accepts supported data only',()=>{assert.equal(skinImage({image:'data:image/jpeg;base64,AA=='}),'data:image/jpeg;base64,AA==');assert.throws(()=>skinImage({image:'https://example.com/image'}));});
test('identification drops model verification claims and unknown concentration',()=>{const p=skinIdentified({product:{name:'包装产品',evidence:'verified',concentration:'1%',ingredients:['视黄醇']}}).product;assert.equal(p.evidence,undefined);assert.equal(p.concentration,undefined);assert.throws(()=>skinIdentified({product:{}}));});
const input={profile:{goals:['保湿']},products:[{id:'p1',name:'面霜',category:'面霜',evidence:'verified',versionConfirmed:true,status:'使用中'}]};
const step={productId:'p1',name:'伪造名称',amount:'按包装',area:'面部',days:[1,3]};
test('plan validates real ids and uses cabinet names',()=>{const normalized=skinInput(input);assert.equal(skinPlanned({plan:{name:'计划',strategy:'基础',morning:[step],evening:[]}},normalized).plan.morning[0].name,'面霜');assert.throws(()=>skinPlanned({plan:{name:'计划',strategy:'基础',morning:[{...step,productId:'fake'}],evening:[]}},normalized));assert.throws(()=>skinPlanned({plan:{name:'计划',strategy:'基础',morning:[{...step,days:[8]}],evening:[]}},normalized));});
test('unknown product excluded and duplicate input rejected',()=>{assert.throws(()=>skinInput({...input,products:[...input.products,...input.products]}));assert.throws(()=>skinPlanned({plan:{name:'计划',strategy:'基础',morning:[step],evening:[]}},skinInput({...input,products:[{...input.products[0],evidence:'ai'}]})));});
