const fs = require('fs');
let json = require('./hosted-zone.json');

console.log(`Updating HostedZoneId to ${process.env.HOSTEDZONENAMEID}`)
console.log(`Updating DNSNAME to ${process.env.ELBDNS}`)

json.Changes[0].ResourceRecordSet.AliasTarget.HostedZoneId = process.env.HOSTEDZONENAMEID;
json.Changes[0].ResourceRecordSet.AliasTarget.DNSName = process.env.ELBDNS;

fs.writeFile("hosted-zone.json", JSON.stringify(json), 'utf8', function (err) {
    if (err) {
        return console.log(err);
    }
    console.log('Updated Hosted Zone File')
});
